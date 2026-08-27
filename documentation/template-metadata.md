# Railway template metadata

Ready-to-paste content for the "Publish" form when turning this project into
a Railway marketplace template (`Project Settings → Generate Template from
Project`, then the publish form).

## Name

```
JODConverter
```

## Short description / tagline

Used in marketplace listings — keep it on one line.

```
Convert Word, Excel and other office documents to PDF (and back) through a simple REST API, powered by headless LibreOffice.
```

## Category

Railway's public "browse by category" list (as of this writing) is: `AI`,
`Analytics`, `Authentication`, `Automation`, `Blog`, `Bot`, `CMS`,
`Observability`, `Queue`, `Starter`, `Storage`. None of these are an exact
match for a document-conversion API. **`Automation`** is the closest fit —
this kind of service is typically wired into a larger workflow (a form
submission, an invoicing pipeline, a document pipeline) rather than used
standalone. Double-check the live dropdown in the publish form, since it may
offer more/different options than the public category pages.

## Long description (About section, Markdown)

Railway's publish form enforces a fixed section structure (it rejects
submissions missing any of the required headings) — this is that exact
structure, filled in. Copy everything between the ```markdown fences below,
verbatim, into the "About" field.

```markdown
# Deploy and Host JODConverter on Railway

JODConverter is a REST API that converts office documents from one format
to another — `docx → pdf`, `xlsx → csv`, `odt → docx`, `html → pdf`, and
most other pairs LibreOffice supports — by wrapping headless LibreOffice
behind a simple HTTP endpoint. Send a file, get back the converted result.

## About Hosting JODConverter

This template packages the official `jodconverter/jodconverter-examples:rest`
image (headless LibreOffice + the JODConverter Spring Boot REST sample)
behind an nginx proxy, so it deploys on Railway with zero configuration:
dynamic `$PORT` binding, sane default upload-size limits, and an optional
API-key gate you can turn on later. There's no database or external
service to provision — one container does the whole job. Budget at least
1GB RAM per instance, since headless LibreOffice conversions are
memory-hungry.

## Common Use Cases

- Converting user-uploaded Word/Excel/PowerPoint documents to PDF from a web or mobile app's backend
- Batch-converting a document archive to a different format (e.g. legacy `.doc`/`.xls` files to `.docx`/`.xlsx` or PDF) as part of a migration pipeline
- Generating PDF exports of reports or invoices produced as `.docx`/`.odt` templates in an internal tool

## Dependencies for JODConverter Hosting

- No external database or managed service required — it's a single self-contained container
- A Railway plan with at least 1GB RAM per instance (headless LibreOffice conversions need it)

### Implementation Details

Once deployed, convert a file with a single request:

```bash
curl -F "data=@document.docx" https://<your-deployment>.up.railway.app/lool/convert-to/pdf -o document.pdf
```

Interactive API docs are available at `/swagger-ui/index.html`. By default
the conversion endpoint has **no authentication** — anyone with the URL
can submit documents. Set the `API_KEYS` variable to a comma-separated
list of keys to require one of them (as an `X-Api-Key` header or an
`apiKey` query parameter) on every request; leave it empty to keep the
service open. Either way, consider keeping it on Railway's private network
and calling it only from your other services if it doesn't need to be
public.

If `API_KEYS` is set, pass one of the configured keys as a header:

```bash
curl -F "data=@document.docx" -H "X-Api-Key: <one-of-your-API_KEYS>" https://<your-deployment>.up.railway.app/lool/convert-to/pdf -o document.pdf
```

or as a query parameter instead, if a header isn't convenient:

```bash
curl -F "data=@document.docx" "https://<your-deployment>.up.railway.app/lool/convert-to/pdf?apiKey=<one-of-your-API_KEYS>" -o document.pdf
```

## Why Deploy JODConverter on Railway?

<!-- Recommended: Keep this section as shown below -->
Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying JODConverter on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.
<!-- End recommended section -->
```

## Template variables (Railway "Generate Template" editor)

Ready to paste into the template editor's variable table — columns match
its own fields (*Variable Name*, *Variable Value*, *Description*, *Mark as
optional*). Every variable is optional: the service runs with zero
configuration, these only override a working default (see
[CLAUDE.md](../CLAUDE.md) "Conventions to preserve").

`PORT` is intentionally **not** listed — Railway injects it automatically
when Public Networking is enabled; exposing it as a template variable
would invite users to break it.

`JODCONVERTER_APP_PORT`, `JODCONVERTER_LOCAL_WORKING_DIR` and
`JAVA_TOOL_OPTIONS` are also **not** listed here — they're internal wiring
(nginx↔Spring Boot port, a temp dir on an ephemeral container filesystem,
JVM tuning flags) with defaults already baked into the `Dockerfile`. No
real deployment scenario needs a template user to touch them; exposing
them would only add noise and a way to break internal plumbing by
accident. They stay documented as advanced settings in the README for
whoever reads the Dockerfile, not as template variables.

| Variable Name | Variable Value | Description | Mark as optional |
|---|---|---|---|
| `API_KEYS` | *(empty)* | Comma-separated list of API keys required to call the conversion endpoint (via `X-Api-Key` header or `apiKey` query param). Leave empty to keep the service open with no authentication. | ✅ Yes |
| `JODCONVERTER_LOCAL_PORT_NUMBERS` | `2002,2003` | Number of parallel LibreOffice conversion workers (one internal port per worker). | ✅ Yes |
| `SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE` | `20MB` | Maximum size accepted for a single uploaded file. | ✅ Yes |
| `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE` | `20MB` | Maximum size accepted for the whole multipart request. Should stay in line with `NGINX_CLIENT_MAX_BODY_SIZE`. | ✅ Yes |
| `NGINX_CLIENT_MAX_BODY_SIZE` | `25m` | Max request body size accepted by the nginx front proxy before it even reaches Spring Boot. Must be **≥** `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE`, otherwise nginx returns 413 first. | ✅ Yes |

## Icon

`icon.svg` next to this file (`documentation/icon.svg`) — a 512×512 rounded-square badge (indigo background,
a white "source" document, a white "target" document with an amber folded
corner, connected by an arrow). It's an original placeholder design (not the
JODConverter/LibreOffice logo, to avoid implying official endorsement) and
renders correctly on both light and dark surfaces since it's a filled badge,
not a transparent glyph.

If Railway's uploader requires a raster format instead of SVG, convert it
first (any of these work):

```bash
# Requires Inkscape
inkscape icon.svg --export-type=png --export-filename=icon.png -w 512 -h 512
```

or open `icon.svg` in a browser and use any online SVG→PNG converter.
