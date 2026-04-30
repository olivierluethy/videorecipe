<?php

declare(strict_types=1);

namespace App\Middleware;

use Psr\Http\Message\ResponseInterface as Response;
use Psr\Http\Message\ServerRequestInterface as Request;
use Psr\Http\Server\MiddlewareInterface;
use Psr\Http\Server\RequestHandlerInterface as Handler;
use Slim\Psr7\Factory\ResponseFactory;

/**
 * Cheap up-front rejection so malformed traffic never reaches the route
 * handler (and never counts against any per-request budget there).
 */
class ValidationMiddleware implements MiddlewareInterface
{
    public function process(Request $request, Handler $handler): Response
    {
        if ($request->getMethod() === 'POST') {
            $type = strtolower($request->getHeaderLine('Content-Type'));
            if (!str_contains($type, 'application/json')) {
                $response = (new ResponseFactory())->createResponse(415);
                $response->getBody()->write((string) json_encode([
                    'error' => 'Expected Content-Type: application/json.',
                ]));
                return $response->withHeader('Content-Type', 'application/json');
            }
        }
        return $handler->handle($request);
    }
}
