<?php

declare(strict_types=1);

namespace App\Routes;

use App\Services\ClaudeException;
use App\Services\ClaudeService;
use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;

class RecipeRoute
{
    public function __construct(
        private readonly ClaudeService $claude,
        private readonly int $maxTranscriptBytes,
    ) {
    }

    public function handle(Request $request, Response $response): Response
    {
        $body = $request->getParsedBody();
        if (!is_array($body)) {
            return $this->error($response, 400, 'Invalid JSON body.');
        }

        $transcript = trim((string) ($body['transcript'] ?? ''));
        $videoId = trim((string) ($body['videoId'] ?? ''));

        if ($transcript === '') {
            return $this->error($response, 400, 'Missing "transcript".');
        }
        if ($videoId === '' || !preg_match('/^[A-Za-z0-9_-]{6,32}$/', $videoId)) {
            return $this->error($response, 400, 'Missing or invalid "videoId".');
        }
        if (strlen($transcript) > $this->maxTranscriptBytes) {
            return $this->error(
                $response,
                413,
                'Transcript exceeds maximum size of ' . $this->maxTranscriptBytes . ' bytes.',
            );
        }

        try {
            $recipe = $this->claude->extractRecipe($transcript, $videoId);
        } catch (ClaudeException $e) {
            // Log full error server-side; return a sanitized message to clients.
            error_log('[ClaudeService] ' . $e->getMessage());
            return $this->error($response, 502, 'Recipe extraction failed. Please try again.');
        }

        $json = json_encode($recipe, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        if ($json === false) {
            return $this->error($response, 500, 'Failed to encode recipe response.');
        }

        $response->getBody()->write($json);
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus(200);
    }

    private function error(Response $response, int $status, string $message): Response
    {
        $response->getBody()->write((string) json_encode(['error' => $message]));
        return $response
            ->withHeader('Content-Type', 'application/json')
            ->withStatus($status);
    }
}
