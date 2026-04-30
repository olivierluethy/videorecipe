<?php

declare(strict_types=1);

namespace App\Middleware;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;
use Slim\Psr7\Factory\ResponseFactory;

/**
 * Per-IP, fixed-window rate limit backed by the local filesystem.
 *
 * Trade-offs: file-based counters are good enough for a single-server
 * deployment with modest traffic; swap to Redis if you horizontally scale.
 *
 * flock() is used to make the read/modify/write step safe under concurrent
 * requests served by the same host.
 */
class RateLimitMiddleware implements MiddlewareInterface
{
    private const WINDOW_SECONDS = 60;

    public function __construct(
        private readonly string $storageDir,
        private readonly int $perMinuteLimit,
    ) {
        if (!is_dir($this->storageDir)) {
            @mkdir($this->storageDir, 0775, true);
        }
    }

    public function process(Request $request, Handler $handler): Response
    {
        // Skip preflight — CorsMiddleware handles those.
        if ($request->getMethod() === 'OPTIONS') {
            return $handler->handle($request);
        }

        $ip = $this->clientIp($request);
        $key = hash('sha256', $ip);
        $file = $this->storageDir . DIRECTORY_SEPARATOR . $key . '.json';

        $now = time();
        $windowStart = $now;
        $count = 0;

        $fp = @fopen($file, 'c+');
        if ($fp === false) {
            // Disk problem — fail open so legitimate users aren't blocked.
            return $handler->handle($request);
        }

        try {
            flock($fp, LOCK_EX);
            $contents = stream_get_contents($fp);
            if (is_string($contents) && $contents !== '') {
                $state = json_decode($contents, true);
                if (is_array($state)
                    && isset($state['windowStart'], $state['count'])
                    && is_numeric($state['windowStart'])
                    && is_numeric($state['count'])
                ) {
                    $windowStart = (int) $state['windowStart'];
                    $count = (int) $state['count'];
                    if ($now - $windowStart >= self::WINDOW_SECONDS) {
                        $windowStart = $now;
                        $count = 0;
                    }
                }
            }
            $count++;

            ftruncate($fp, 0);
            rewind($fp);
            fwrite($fp, (string) json_encode([
                'windowStart' => $windowStart,
                'count' => $count,
            ]));
            fflush($fp);
        } finally {
            flock($fp, LOCK_UN);
            fclose($fp);
        }

        if ($count > $this->perMinuteLimit) {
            $resetIn = max(1, self::WINDOW_SECONDS - ($now - $windowStart));
            $response = (new ResponseFactory())->createResponse(429);
            $response->getBody()->write((string) json_encode([
                'error' => 'Rate limit exceeded. Please wait a moment and try again.',
                'retryAfter' => $resetIn,
            ]));
            return $response
                ->withHeader('Content-Type', 'application/json')
                ->withHeader('Retry-After', (string) $resetIn);
        }

        return $handler->handle($request);
    }

    private function clientIp(Request $request): string
    {
        // Trust X-Forwarded-For when present (most managed PHP hosts and CDN
        // setups put it there). We take the leftmost value, which is the
        // origin client per RFC 7239.
        $xff = $request->getHeaderLine('X-Forwarded-For');
        if ($xff !== '') {
            $first = trim(explode(',', $xff)[0]);
            if ($first !== '') {
                return $first;
            }
        }
        $params = $request->getServerParams();
        return is_string($params['REMOTE_ADDR'] ?? null)
            ? $params['REMOTE_ADDR']
            : '0.0.0.0';
    }
}
