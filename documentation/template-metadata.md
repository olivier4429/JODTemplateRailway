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

```markdown
# JODConverter

A REST API for converting office documents — powered by [JODConverter](https://github.com/jodconverter)
and headless LibreOffice. Send a file, get back a different format:
`docx → pdf`, `xlsx → csv`, `odt → docx`, `html → pdf`, and most other
LibreOffice-supported format pairs.

## Quick start

```bash
curl -F "data=@document.docx" https://<your-deployment>.up.railway.app/lool/convert-to/pdf -o document.pdf
```

Interactive API docs are available at `/swagger-ui/index.html` once deployed.

## What's inside

This template wraps the official `jodconverter/jodconverter-examples:rest`
image (LibreOffice + the JODConverter Spring Boot REST sample) with the
glue needed to run cleanly on Railway: dynamic port binding and sane
default resource settings.

## 🔑 Optional API-key protection

By default, the conversion endpoint has **no authentication** — anyone
with the URL can submit documents for conversion. Set the `API_KEYS`
variable to a comma-separated list of keys to require one of them (as an
`X-Api-Key` header or an `apiKey` query parameter) on every request; leave
it empty to keep the service open. Either way, consider keeping it on
Railway's private network and calling it only from your other services if
it doesn't need to be public.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `API_KEYS` | *(empty)* | Comma-separated API keys allowed to call the conversion API; empty = unrestricted |
| `JODCONVERTER_LOCAL_PORT_NUMBERS` | `2002,2003` | Number of parallel LibreOffice conversion instances |
| `SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE` | `20MB` | Max uploaded file size |
| `SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE` | `20MB` | Max multipart request size |

Budget at least 1GB RAM per instance — headless LibreOffice is memory-hungry.
```

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
