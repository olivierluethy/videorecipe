# videorecipe-backend

Tiny PHP proxy that the Flutter app talks to instead of calling Anthropic
directly. The Anthropic API key lives only on the server.

## Endpoints

| Method | Path                      | Purpose                          |
|--------|---------------------------|----------------------------------|
| POST   | `/api/extract-recipe`     | Send transcript, get recipe JSON |
| GET    | `/api/health`             | Liveness check                   |

### POST `/api/extract-recipe`

Request body:

```json
{
  "transcript": "<plain-text transcript or description, ≤ MAX_TRANSCRIPT_BYTES>",
  "videoId": "dQw4w9WgXcQ"
}
```

Successful response (HTTP 200):

```json
{
  "dishName": "Beef Wellington",
  "description": "...",
  "totalTimeMinutes": 90,
  "difficulty": "hard",
  "servings": 4,
  "ingredients": [{"name": "Beef tenderloin", "quantity": "1 kg"}],
  "steps": ["Sear the beef.", "..."],
  "tips": ["..."]
}
```

Error responses:

| Status | Meaning                                                                 |
|--------|-------------------------------------------------------------------------|
| 400    | Missing/invalid `transcript` or `videoId`.                              |
| 413    | Transcript exceeds `MAX_TRANSCRIPT_BYTES`.                              |
| 415    | Wrong `Content-Type` (must be `application/json`).                      |
| 429    | Rate limit hit; honors `Retry-After` header.                            |
| 502    | Upstream Claude error (logged server-side, sanitized for the client).   |

## Local development

```bash
cd backend
composer install
cp .env.example .env       # then put your real ANTHROPIC_API_KEY in .env
php -S localhost:8000 -t public
```

Smoke test:

```bash
curl http://localhost:8000/api/health
curl -X POST http://localhost:8000/api/extract-recipe \
  -H 'Content-Type: application/json' \
  -d '{"transcript":"Today we make pancakes...","videoId":"abc12345"}'
```

For a phone on the same Wi-Fi (e.g. the S21), bind to your LAN IP:

```bash
php -S 0.0.0.0:8000 -t public
```

…and run the Flutter app with:

```bash
flutter run --dart-define=BACKEND_BASE_URL=http://<your-laptop-lan-ip>:8000
```

Production is hosted at `https://receipt.prompt-in.com`, which is also the
default `BackendConfig.baseUrl` — release builds don't need any
`--dart-define`.

## Deployment notes

- **HTTPS only in production.** Configure SSL via the host (Let's Encrypt
  or built-in cert).
- **Document root.** Point the host's docroot at `public/` if possible. If
  not (cPanel-style shared hosting), the root `.htaccess` rewrites
  everything to `public/` so `vendor/`, `src/`, and `.env` stay private.
- **`.env`.** Either use the host's environment-variable panel, or upload a
  `.env` file *outside* the web root and update the bootstrap path. The
  default loader looks at the project root.
- **Rate-limit storage.** `data/ratelimit/` is created automatically and
  must be writable by the PHP user. On most hosts that's already the case.
- **App attestation (recommended for production).** Add iOS App Attest /
  Android Play Integrity validation in `ValidationMiddleware` before
  shipping publicly.

## Project layout

```
backend/
├── composer.json
├── .env.example
├── .htaccess               # rewrites to public/ (only matters if docroot is project root)
├── public/
│   ├── index.php           # Slim bootstrap
│   └── .htaccess           # all routes → index.php
├── src/
│   ├── Routes/
│   │   └── RecipeRoute.php
│   ├── Services/
│   │   └── ClaudeService.php
│   └── Middleware/
│       ├── CorsMiddleware.php
│       ├── RateLimitMiddleware.php
│       └── ValidationMiddleware.php
└── data/                   # rate-limit counters; gitignored
```
