<?php

declare(strict_types=1);

namespace App\Middleware;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;
use Slim\Psr7\Factory\ResponseFactory;

/**
 * Mobile apps don't enforce CORS, so the main reason this exists is to keep
 * dev-time browser testing painless. Tighten ALLOWED_ORIGINS once a web
 * client is added.
 */
class CorsMiddleware implements MiddlewareInterface
{
    public function __construct(
        private readonly string $allowedOrigins = '*',
    ) {
    }

    public function process(Request $request, Handler $handler): Response
    {
        // Short-circuit preflight without running the rest of the stack.
        if (strtoupper($request->getMethod()) === 'OPTIONS') {
            $response = (new ResponseFactory())->createResponse(204);
            return $this->withCorsHeaders($response);
        }

        $response = $handler->handle($request);
        return $this->withCorsHeaders($response);
    }

    private function withCorsHeaders(Response $response): Response
    {
        return $response
            ->withHeader('Access-Control-Allow-Origin', $this->allowedOrigins)
            ->withHeader('Access-Control-Allow-Methods', 'POST, GET, OPTIONS')
            ->withHeader('Access-Control-Allow-Headers', 'Content-Type')
            ->withHeader('Access-Control-Max-Age', '600')
            ->withHeader('Vary', 'Origin');
    }
}
