# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this repo is

A Railway "template" repo — not an app with its own source code. It wraps
the official `ghcr.io/jodconverter/jodconverter-examples:rest` image
(LibreOffice + the JODConverter `spring-boot-rest` sample, from
[jodconverter/docker-image-jodconverter-examples](https://github.com/jodconverter/docker-image-jodconverter-examples))
so it deploys cleanly on Railway. There is no Java/Spring source here to
edit — the app itself is baked into the upstream image; this repo only
adds a thin layer around it.

## Architecture

```
Railway --($PORT)--> nginx --($JODCONVERTER_APP_PORT, fixed, default 8088)--> Spring Boot (JODConverter)
```

- `Dockerfile` — `FROM` the upstream jodconverter image, `apt-get install`s
  `nginx` + `gettext-base` (for `envsubst`), copies `docker/*`.
- `railway-entrypoint.sh` (the container `ENTRYPOINT`) does three things on
  every start:
  1. Builds `/etc/nginx/conf.d/api_keys.map` and `/etc/nginx/conf.d/auth.conf`
     from the `API_KEYS` env var (see below).
  2. Renders `/etc/nginx/nginx.conf` from `docker/nginx.conf.template` via
     `envsubst`, substituting only `LISTEN_PORT`, `BACKEND_PORT`,
     `NGINX_CLIENT_MAX_BODY_SIZE` — every other `$var` in the template
     (nginx's own: `$http_x_api_key`, `$host`, ...) must stay untouched, so
     the `envsubst 'LIST'` call must keep naming exactly those three.
  3. Starts the upstream `/docker-entrypoint.sh` (the Spring Boot app) and
     `nginx -g 'daemon off;'` side by side in the background, then
     `wait -n` on both and tears down the other if either dies (so
     Railway's restart policy in `railway.json` can kick in).
- The Spring Boot app never binds `$PORT` directly anymore — it's fixed on
  `JODCONVERTER_APP_PORT` (`SERVER_PORT` env, Spring's relaxed binding) so
  nginx has a stable backend to proxy to regardless of what Railway assigns
  as the public port.

## The API key gate

Optional, off by default (`API_KEYS=""` — fully backward compatible). Set
`API_KEYS` to a comma-separated list; `railway-entrypoint.sh` writes each
trimmed key as an nginx `map` entry, and requests to any path except
`/swagger-ui/*` and `/v3/api-docs` must then present one of them via the
`X-Api-Key` header or the `apiKey` query parameter, else nginx returns 401.
Those two doc paths are intentionally always open — that's also what keeps
Railway's healthcheck (`GET /swagger-ui/index.html`, see `railway.json`)
working no matter how `API_KEYS` is set.

When touching this: the matching logic lives in
`docker/nginx.conf.template` (three `map` blocks + `include
/etc/nginx/conf.d/auth.conf`), not in `railway-entrypoint.sh` — the script
only generates the two small include files consumed by the template.

## Testing changes

No unit tests / CI in this repo. Docker isn't available in this sandbox
(`docker` CLI absent), so changes to the Dockerfile/entrypoint/nginx config
can't be built or run here — reason through them carefully instead of
assuming a build will catch mistakes, and mention that a real `docker
build` + `docker run` (see README §1) is the actual verification step.

`scripts/test-convert.sh` / `.ps1` are the smoke tests once a container is
actually running; both take an optional API key argument now.

## Conventions to preserve

- Every default must keep the template working with **zero configuration**
  (this is what "template" means on Railway's marketplace) — new features
  are opt-in via env vars, never a required step.
- Comments in `Dockerfile` / `railway-entrypoint.sh` / `docker/*.conf*`
  explain *why*, matching the existing style — assume the next reader
  doesn't know Railway's `$PORT` convention or nginx `map` syntax.
- Keep `README.md`'s env var table, repository layout tree, and
  troubleshooting list in sync with actual behavior — they're the primary
  docs a template user reads before touching the code.
- `documentation/template-metadata.md` is copy-pasted verbatim into
  Railway's "Publish Template" form — keep its env var table and
  description in sync with the README when either changes.
