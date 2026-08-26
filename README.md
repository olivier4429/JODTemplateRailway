# JODConverter on Railway

Railway template to deploy a document conversion service based on
[JODConverter](https://github.com/jodconverter) (headless LibreOffice driven
by the JODConverter Java API, exposed over REST via Spring Boot).

The exposed service can convert pretty much any format pair supported by
LibreOffice: `docx` → `pdf`, `xlsx` → `csv`, `odt` → `docx`, `html` → `pdf`,
etc.

## How it works

This template does not reinvent the wheel: it builds on the official Docker
image maintained by the `jodconverter` GitHub organization
([`ghcr.io/jodconverter/jodconverter-examples:rest`](https://github.com/jodconverter/docker-image-jodconverter-examples)),
which bundles:

- LibreOffice (headless mode, driven by one or more `soffice` instances)
- The `spring-boot-rest` sample application from the
  [`jodconverter/jodconverter-samples`](https://github.com/jodconverter/jodconverter-samples)
  repository
- A built-in Swagger UI

On top of that image, this repo adds a **Dockerfile** that puts an `nginx`
reverse proxy in front of the app. That proxy does two things:

- wires up the dynamic `$PORT` Railway provides at runtime (nginx binds
  `$PORT`; the Spring Boot app itself always listens on a fixed internal
  port, see [Environment variables](#3-environment-variables));
- optionally gates every conversion call behind one of a list of API keys
  (see [Securing access](#4-securing-access-recommended)).

Repository layout:

```
.
├── Dockerfile              # builds on the official jodconverter image, adds the nginx proxy
├── railway-entrypoint.sh   # renders nginx.conf, starts the app + nginx side by side
├── docker/
│   ├── nginx.conf.template   # nginx config template (rendered at container start)
│   └── proxy_common.conf     # shared proxy_pass settings, included from the template
├── railway.json            # Railway config (Dockerfile builder, healthcheck, restart policy)
├── .dockerignore
├── .gitattributes          # forces LF endings on scripts/configs copied into the Linux image
├── scripts/
│   ├── test-convert.sh     # quick bash/curl smoke test (optionally sends an API key)
│   └── test-convert.ps1    # quick PowerShell smoke test (optionally sends an API key)
├── documentation/
│   ├── icon.svg              # marketplace template icon
│   └── template-metadata.md  # name/description/category to paste when publishing
└── README.md
```

## 1. Test locally with Docker

Prerequisite: Docker Desktop installed and running.

```powershell
docker build -t jodconverter-railway .
docker run --rm -p 8080:8080 -e PORT=8080 jodconverter-railway
```

> Budget 512 MB to 1 GB of RAM for the container (LibreOffice + JVM). Add
> `--memory 1g` to the `docker run` command to mimic Railway's limits.

Once it's up (the first LibreOffice startup can take 20-40 seconds), check
that the API responds:

```powershell
# Swagger UI docs
Start-Process http://localhost:8080/swagger-ui/index.html

# Conversion test (requires a source file, e.g. sample.docx)
.\scripts\test-convert.ps1 -SrcFile .\sample.docx -Format pdf
```

On bash/WSL/macOS/Linux:

```bash
./scripts/test-convert.sh http://localhost:8080 ./sample.docx pdf
```

> To try the [API key gate](#4-securing-access-recommended) locally, run
> with `-e API_KEYS=test-key` and pass `-ApiKey test-key` /
> `test-key` as the scripts' extra argument.

### Calling the API directly

```bash
curl -F "data=@sample.docx" http://localhost:8080/lool/convert-to/pdf -o sample.pdf
```

- Endpoint: `POST /lool/convert-to/{format}` (or `POST /lool/convert-to?format=pdf`)
- Required multipart field: `data` (the file to convert)
- Response: the converted file as binary (`application/octet-stream`)
- Interactive docs: `GET /swagger-ui/index.html` (used as the healthcheck endpoint — it's a static asset, so it can't be broken by an OpenAPI schema-generation quirk)
- Raw OpenAPI spec: `GET /v3/api-docs`

## 2. Deploy this project on Railway

1. Push this folder to a GitHub repository (public or private).

   ```bash
   git init
   git add .
   git commit -m "JODConverter Railway template"
   git branch -M main
   git remote add origin https://github.com/<your-account>/<your-repo>.git
   git push -u origin main
   ```

2. On [railway.com](https://railway.com/), create a new project:
   **New Project → Deploy from GitHub repo**, then select your repository.
3. Railway automatically detects the `Dockerfile` (and reads `railway.json`
   for the healthcheck and restart policy) — no extra configuration is
   needed for a first deployment.
4. Under **Settings → Networking**, enable **Public Networking** to get a
   public URL (`https://<your-service>.up.railway.app`), or leave it on
   private networking only if the service is only called by other services
   in the same Railway project.
5. Wait for the build/deploy to finish, then test:

   ```bash
   curl -F "data=@sample.docx" https://<your-service>.up.railway.app/lool/convert-to/pdf -o sample.pdf
   ```

### Sizing

- **RAM**: budget at least **1 GB** per instance (headless LibreOffice is
  memory-hungry). On RAM-constrained plans, reduce the number of LibreOffice
  instances via `JODCONVERTER_LOCAL_PORT_NUMBERS` (see table below) down to
  a single value, e.g. `2002`.
- **Cold start**: the first LibreOffice + JVM startup can take 30 to 60
  seconds. `railway.json`'s `healthcheckTimeout` is set to 120s to leave
  room for that; raise it further if deployment consistently fails the
  healthcheck on a very CPU-constrained plan.
- **Horizontal scaling**: each configured LibreOffice instance handles one
  conversion at a time. To absorb more load, increase
  `JODCONVERTER_LOCAL_PORT_NUMBERS` (more instances per container) and/or
  the number of service replicas on Railway.

## 3. Environment variables

Any Spring Boot / JODConverter property can be overridden without
rebuilding the image, by setting it as a service variable in Railway's
**Variables** tab (Spring Boot relaxed binding: `MY_PROPERTY` ↔
`my.property`).

| Variable | Default (Dockerfile) | Purpose |
|---|---|---|
| `PORT` | `8080` | Railway's own convention: the port its proxy **and healthcheck system** target. Railway does not infer this from the Dockerfile's `EXPOSE`, so it's baked in here as a default. This is the port **nginx** binds; the Spring Boot app itself always listens on `JODCONVERTER_APP_PORT`. Override it in the Variables tab only if you know Railway assigned a different one for your plan/region. |
| `JODCONVERTER_APP_PORT` | `8088` | Fixed internal port the Spring Boot app listens on, behind nginx. Only change this if `8088` conflicts with something else in a custom setup — Railway never talks to it directly. |
| `API_KEYS` | *(empty)* | Comma-separated list of API keys allowed to call the conversion API, e.g. `key-team-a,key-team-b`. Leave unset/empty to keep the service open (the default, same behavior as before). See [Securing access](#4-securing-access-recommended). |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `25m` | Max request body size accepted by nginx. Should stay at or above `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE`, or large uploads get rejected by nginx before reaching Spring Boot. |
| `JODCONVERTER_LOCAL_PORT_NUMBERS` | `2002,2003` | List of internal LibreOffice ports = number of parallel conversion instances |
| `JODCONVERTER_LOCAL_WORKING_DIR` | `/tmp` | Temporary working directory for conversions |
| `SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE` | `20MB` | Max size of an uploaded file |
| `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE` | `20MB` | Max size of the multipart request |
| `JAVA_TOOL_OPTIONS` | `-XX:MaxRAMPercentage=75 -XX:InitialRAMPercentage=50` | Caps the JVM heap to a fraction of the container's RAM to avoid OOM-kills |

## 4. Securing access (recommended)

By default, the conversion endpoint has **no authentication**: anyone who
knows the public URL can send documents to be converted. This template now
ships an optional API-key gate (an `nginx` reverse proxy in front of the
Spring Boot app, wired up in `railway-entrypoint.sh` /
`docker/nginx.conf.template`) to close that gap without extra
infrastructure:

- Set the `API_KEYS` service variable to a comma-separated list of keys,
  e.g. `API_KEYS=key-for-team-a,key-for-team-b`.
- Callers must then send one of those keys on every request, either as a
  header or as a query parameter:

  ```bash
  curl -F "data=@sample.docx" \
    -H "X-Api-Key: key-for-team-a" \
    https://<your-service>.up.railway.app/lool/convert-to/pdf -o sample.pdf

  # or, equivalently:
  curl -F "data=@sample.docx" \
    "https://<your-service>.up.railway.app/lool/convert-to/pdf?apiKey=key-for-team-a" \
    -o sample.pdf
  ```

- A request with a missing or invalid key gets `401 Unauthorized`.
- `GET /swagger-ui/*` and `GET /v3/api-docs` always stay reachable without a
  key — they're just documentation, and this is also what lets Railway's
  own healthcheck (`GET /swagger-ui/index.html`) keep working no matter
  how `API_KEYS` is set.
- Leaving `API_KEYS` unset (the default) keeps the service open, exactly
  as before — this is an opt-in feature, not a breaking change.

This is a lightweight allowlist, not a full auth system (no per-key rate
limiting, expiry or scoping) — treat each key as a shared secret and rotate
it by updating the `API_KEYS` variable. Combine with either of these for
extra defense in depth:

- **Internal use only**: disable *Public Networking* and keep the service
  reachable only over Railway's private network
  (`<service>.railway.internal`) from other services in the same project.
- **Public use**: additionally put the service behind your own API
  gateway or application backend if you need per-caller rate limiting,
  usage tracking, or key rotation without redeploying.

## 5. Turning this project into a reusable Railway Template

This corresponds to the marketplace sense of "template" (a reusable
"Deploy Now" button for others), on top of the plain project deployment
from step 2.

1. First deploy the project normally (step 2) to confirm it works.
2. In the Railway project, go to **Project Settings → Generate Template
   from Project**, then click **Create Template**
   (see [docs.railway.com/templates/create](https://docs.railway.com/templates/create)).
3. In the template editor, for the JODConverter service:
   - **Variables**: expose the ones from the table above with sensible
     defaults, so template users can tweak them without reading the code.
   - **Settings → Healthcheck Path**: `/swagger-ui/index.html` (matches
     `railway.json`).
   - **Settings → Public Networking**: enable it if you want the template
     to expose an HTTP URL directly.
4. Add a description, an icon and a category to the template, then
   **Publish** to make it available (and, if you want, eligible for
   sharing on the public Railway marketplace).
5. The published template generates a `https://railway.com/deploy/<id>`
   link you can share: anyone who clicks it gets an independent copy of
   the service, with your default variables pre-filled.

## Troubleshooting

- **Healthcheck fails with "service unavailable" on every attempt, for the
  full retry window, even though the deploy logs show Spring Boot/Tomcat
  started fine within a few seconds**: this is not a slow-startup problem —
  it means Railway's healthcheck subsystem doesn't know which port to call.
  Railway reads the `PORT` env var to route both its proxy *and* its
  healthchecks; it does **not** derive it from the Dockerfile's `EXPOSE`
  instruction. This template now bakes `ENV PORT=8080` into the Dockerfile
  as a safe default, but if you still hit this, explicitly add a `PORT`
  service variable (Settings → Variables) set to `8080` (or whatever value
  matches your `SERVER_PORT`/`EXPOSE`). See
  [Railway — Healthchecks](https://docs.railway.com/deployments/healthchecks)
  and this [reported case](https://station.railway.com/questions/healthcheck-service-unavailable-but-en-b056fa2c)
  with the same symptom.
- **Healthcheck genuinely times out because the app is still starting**: on
  a CPU-constrained plan the first LibreOffice startup can take longer.
  Increase `healthcheckTimeout` in `railway.json`.
- **`OutOfMemoryError` / container restarting in a loop**: the Railway plan
  doesn't have enough RAM for the configured number of LibreOffice
  instances. Reduce `JODCONVERTER_LOCAL_PORT_NUMBERS` to a single value
  (`2002`) or increase the RAM allocated to the service.
- **413 / file size error**: increase
  `SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE` and
  `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE`.
- **500 on a specific format**: check that LibreOffice actually supports
  that format pair (see the LibreOffice filter list); not every pair is
  natively supported.
- **401 Unauthorized**: `API_KEYS` is set on the service, and the request
  didn't include a matching key. Add `-H "X-Api-Key: <one-of-the-keys>"`
  (or `?apiKey=<one-of-the-keys>` on the URL). `GET /swagger-ui/*` and
  `/v3/api-docs` never require a key.

## References

- [jodconverter/docker-image-jodconverter-examples](https://github.com/jodconverter/docker-image-jodconverter-examples) — official Docker image used as the base
- [jodconverter/jodconverter-samples](https://github.com/jodconverter/jodconverter-samples) — source of the embedded REST API (`samples/spring-boot-rest` module)
- [Railway — Config as Code](https://docs.railway.com/config-as-code/reference)
- [Railway — Create a Template](https://docs.railway.com/templates/create)
- [Railway — Deploy a Template](https://docs.railway.com/templates/deploy)
