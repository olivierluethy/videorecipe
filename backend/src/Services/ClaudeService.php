<?php

declare(strict_types=1);

namespace App\Services;

use GuzzleHttp\Client;
use GuzzleHttp\Exception\GuzzleException;

class ClaudeException extends \RuntimeException
{
}

class ClaudeService
{
    private const ENDPOINT = 'https://api.anthropic.com/v1/messages';
    private const ANTHROPIC_VERSION = '2023-06-01';
    private const MAX_TOKENS = 3072;

    private const SYSTEM_PROMPT = <<<TXT
You are a recipe extraction assistant. Given the transcript and metadata of a YouTube cooking video, extract the recipe and return ONLY valid JSON (no markdown, no commentary, no code fences) in this exact structure:

{
  "dishName": "string",
  "description": "one or two sentences",
  "totalTimeMinutes": integer,
  "difficulty": "easy" | "medium" | "hard",
  "servings": integer,
  "ingredients": [{"name": "string", "quantity": "string"}],
  "steps": ["string", "string"],
  "tips": ["string"]
}

Rules:
- Use the most natural, common name for the dish.
- Quantities should be concise (e.g., "2 cups", "1 tbsp", "to taste").
- Steps should be in chronological order, concise, action-first imperative.
- If a value is genuinely unknown, make a reasonable best-guess based on the cuisine/dish (do not return null or empty).
- Output JSON only. No prose, no markdown.
TXT;

    private Client $client;

    public function __construct(
        private readonly string $apiKey,
        private readonly string $model,
        ?Client $client = null,
    ) {
        $this->client = $client ?? new Client([
            'timeout' => 90,
            'connect_timeout' => 30,
        ]);
    }

    /**
     * @return array<string, mixed> The recipe payload as returned by Claude
     *                              (already parsed from the model's text block).
     */
    public function extractRecipe(string $transcript, string $videoId): array
    {
        if ($this->apiKey === '') {
            throw new ClaudeException('Server is missing ANTHROPIC_API_KEY.');
        }

        $userContent = "Video ID: {$videoId}\n\nTranscript / description:\n{$transcript}";

        $body = [
            'model' => $this->model,
            'max_tokens' => self::MAX_TOKENS,
            'system' => [
                [
                    'type' => 'text',
                    'text' => self::SYSTEM_PROMPT,
                    'cache_control' => ['type' => 'ephemeral'],
                ],
            ],
            'messages' => [
                [
                    'role' => 'user',
                    'content' => [
                        ['type' => 'text', 'text' => $userContent],
                    ],
                ],
            ],
        ];

        try {
            $response = $this->client->post(self::ENDPOINT, [
                'headers' => [
                    'x-api-key' => $this->apiKey,
                    'anthropic-version' => self::ANTHROPIC_VERSION,
                    'content-type' => 'application/json',
                ],
                'json' => $body,
                'http_errors' => false,
            ]);
        } catch (GuzzleException $e) {
            throw new ClaudeException('Network error reaching Claude: ' . $e->getMessage(), 0, $e);
        }

        $status = $response->getStatusCode();
        $rawBody = (string) $response->getBody();
        $payload = json_decode($rawBody, true);

        if ($status >= 400) {
            $message = is_array($payload) && isset($payload['error']['message'])
                ? (string) $payload['error']['message']
                : "Claude API returned HTTP {$status}";
            throw new ClaudeException($message);
        }

        if (!is_array($payload)) {
            throw new ClaudeException('Unexpected (non-JSON) response from Claude.');
        }

        $textBlock = null;
        foreach (($payload['content'] ?? []) as $block) {
            if (is_array($block) && ($block['type'] ?? '') === 'text') {
                $textBlock = $block;
                break;
            }
        }
        if ($textBlock === null) {
            throw new ClaudeException('Claude returned no text content.');
        }

        return $this->parseRecipeJson((string) ($textBlock['text'] ?? ''));
    }

    /**
     * @return array<string, mixed>
     */
    private function parseRecipeJson(string $raw): array
    {
        $text = trim($raw);

        // Strip ```json ... ``` fences if the model adds them despite instructions.
        if (str_starts_with($text, '```')) {
            $text = (string) preg_replace('/^```(?:json)?\s*/', '', $text);
            $text = trim($text);
            if (str_ends_with($text, '```')) {
                $text = trim(substr($text, 0, -3));
            }
        }

        $first = strpos($text, '{');
        $last = strrpos($text, '}');
        if ($first === false || $last === false || $last <= $first) {
            throw new ClaudeException('Claude did not return valid JSON.');
        }

        $candidate = substr($text, $first, $last - $first + 1);
        $decoded = json_decode($candidate, true);
        if (!is_array($decoded)) {
            throw new ClaudeException('Failed to parse recipe JSON: ' . json_last_error_msg());
        }
        return $decoded;
    }
}
