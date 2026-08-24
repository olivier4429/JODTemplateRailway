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

The only thing this repo adds is a **Dockerfile** wrapping that image with a
small entrypoint script that wires up the dynamic `$PORT` Railway provides at
runtime (Spring Boot listens on `server.port`, which needs to match whatever
port Railway expects).

Repository layout:

```
.
├── Dockerfile              # builds on the official jodconverter image, wires up $PORT
├── railway-entrypoint.sh   # translates $PORT -> SERVER_PORT before starting the app
├── railway.json            # Railway config (Dockerfile builder, healthcheck, restart policy)
├── .dockerignore
├── scripts/
│   ├── test-convert.sh     # quick bash/curl smoke test
│   └── test-convert.ps1    # quick PowerShell smoke test
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

### Calling the API directly

```bash
curl -F "data=@sample.docx" http://localhost:8080/lool/convert-to/pdf -o sample.pdf
```

- Endpoint: `POST /lool/convert-to/{format}` (or `POST /lool/convert-to?format=pdf`)
- Required multipart field: `data` (the file to convert)
- Response: the converted file as binary (`application/octet-stream`)
- Interactive docs: `GET /swagger-ui/index.html`
- Raw OpenAPI spec: `GET /v3/api-docs` (used as the healthcheck endpoint)

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
| `PORT` | provided by Railway | Public port Railway expects; automatically translated into `SERVER_PORT` |
| `JODCONVERTER_LOCAL_PORT_NUMBERS` | `2002,2003` | List of internal LibreOffice ports = number of parallel conversion instances |
| `JODCONVERTER_LOCAL_WORKING_DIR` | `/tmp` | Temporary working directory for conversions |
| `SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE` | `20MB` | Max size of an uploaded file |
| `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE` | `20MB` | Max size of the multipart request |
| `JAVA_TOOL_OPTIONS` | `-XX:MaxRAMPercentage=75 -XX:InitialRAMPercentage=50` | Caps the JVM heap to a fraction of the container's RAM to avoid OOM-kills |

## 4. Securing access (recommended)

The official image ships with **no authentication** on the conversion
endpoint: anyone who knows the public URL can send documents to be
converted. Two simple options depending on your use case:

- **Internal use only**: disable *Public Networking* and keep the service
  reachable only over Railway's private network
  (`<service>.railway.internal`) from other services in the same project.
- **Public use**: put the service behind a gateway that checks an API key
  before relaying the request (e.g. a small separate Railway service based
  on Caddy/nginx requiring an `Authorization` header, or a function in your
  application backend that proxies to this service over Railway's private
  network instead of exposing it directly). This is deliberately left out
  of this template to keep it simple and easy to evolve.

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
   - **Settings → Healthcheck Path**: `/v3/api-docs` (matches
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

- **Healthcheck keeps failing**: the service takes longer than
  `healthcheckTimeout` to start (often on a CPU-constrained plan during the
  first LibreOffice startup). Increase `healthcheckTimeout` in
  `railway.json`.
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

## References

- [jodconverter/docker-image-jodconverter-examples](https://github.com/jodconverter/docker-image-jodconverter-examples) — official Docker image used as the base
- [jodconverter/jodconverter-samples](https://github.com/jodconverter/jodconverter-samples) — source of the embedded REST API (`samples/spring-boot-rest` module)
- [Railway — Config as Code](https://docs.railway.com/config-as-code/reference)
- [Railway — Create a Template](https://docs.railway.com/templates/create)
- [Railway — Deploy a Template](https://docs.railway.com/templates/deploy)
