<?php

declare(strict_types=1);

require __DIR__ . '/../vendor/autoload.php';

use App\Middleware\CorsMiddleware;
use App\Middleware\RateLimitMiddleware;
use App\Middleware\ValidationMiddleware;
use App\Routes\RecipeRoute;
use App\Services\ClaudeService;
use Dotenv\Dotenv;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Slim\Factory\AppFactory;

$rootDir = dirname(__DIR__);

// .env is optional in production (hosts often use real environment variables).
$dotenv = Dotenv::createImmutable($rootDir);
$dotenv->safeLoad();

// Tiny env helper that prefers $_ENV, then getenv(), then a default.
$env = static function (string $key, string $default = ''): string {
    $value = $_ENV[$key] ?? getenv($key);
    return is_string($value) && $value !== '' ? $value : $default;
};

$apiKey            = $env('ANTHROPIC_API_KEY');
$model             = $env('ANTHROPIC_MODEL', 'claude-haiku-4-5-20251001');
$allowedOrigins    = $env('ALLOWED_ORIGINS', '*');
$rateLimit         = (int) $env('RATE_LIMIT_PER_MINUTE', '10');
$maxTranscriptBytes = (int) $env('MAX_TRANSCRIPT_BYTES', '200000');
$appEnv            = $env('APP_ENV', 'production');

$app = AppFactory::create();

// Body parsing has to be added before route handlers see the request, but
// after the outer middleware that filters traffic. Slim runs middleware in
// LIFO order: the LAST add() is the OUTERMOST.
//
// Final order on a real request:
//   CORS  →  RateLimit  →  Validation  →  body parsing  →  route handler
$app->addBodyParsingMiddleware();
$app->add(new ValidationMiddleware());
$app->add(new RateLimitMiddleware(
    storageDir: $rootDir . '/data/ratelimit',
    perMinuteLimit: $rateLimit,
));
$app->add(new CorsMiddleware($allowedOrigins));

// Hide stack traces in production. The error middleware still logs server-side.
$showErrors = $appEnv !== 'production';
$app->addErrorMiddleware($showErrors, true, true);

$claudeService = new ClaudeService(apiKey: $apiKey, model: $model);
$recipeRoute = new RecipeRoute(
    claude: $claudeService,
    maxTranscriptBytes: $maxTranscriptBytes,
);

$app->post('/api/extract-recipe', [$recipeRoute, 'handle']);

$app->get('/api/health', function (ServerRequestInterface $req, ResponseInterface $res): ResponseInterface {
    $res->getBody()->write((string) json_encode(['status' => 'ok']));
    return $res->withHeader('Content-Type', 'application/json');
});

// Catch-all OPTIONS so CorsMiddleware can answer arbitrary preflights.
$app->options('/{routes:.+}', function (ServerRequestInterface $req, ResponseInterface $res): ResponseInterface {
    return $res;
});

$app->run();
