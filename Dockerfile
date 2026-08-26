# Railway template for JODConverter (document conversion via LibreOffice)
#
# This builds on top of the official JODConverter "rest" sample image, which
# bundles LibreOffice + the jodconverter-spring-boot-starter REST sample app.
# See: https://github.com/jodconverter/docker-image-jodconverter-examples
#
# On top of that image, this Dockerfile adds:
#  - an nginx reverse proxy so the app listens on the dynamic $PORT that
#    Railway injects at runtime (nginx binds $PORT; the Spring Boot app
#    itself stays on a fixed internal port, see JODCONVERTER_APP_PORT below)
#  - optional API-key gating in front of the conversion API (see API_KEYS)
#  - a few sane default environment variables
ARG JODCONVERTER_IMAGE_TAG=rest
FROM ghcr.io/jodconverter/jodconverter-examples:${JODCONVERTER_IMAGE_TAG}

# nginx: the reverse proxy / API-key gate in front of the Spring Boot app.
# gettext-base: provides envsubst, used to render nginx.conf.template at
# container startup (see railway-entrypoint.sh).
RUN apt-get update \
    && apt-get install -y --no-install-recommends nginx gettext-base \
    && rm -rf /var/lib/apt/lists/*

COPY docker/nginx.conf.template /etc/nginx/nginx.conf.template
COPY docker/proxy_common.conf /etc/nginx/conf.d/proxy_common.conf

# Sensible defaults; all of these can be overridden as Railway service
# variables without rebuilding the image (Spring Boot relaxed binding
# maps SCREAMING_SNAKE_CASE env vars to their dotted property names).
#
# PORT is Railway's own convention: its healthcheck/proxy subsystem needs
# an explicit PORT value to know which port to talk to and does NOT infer
# it from this file's EXPOSE instruction. Baking a default here means the
# template works out of the box; it can still be overridden from the
# Railway dashboard (Variables tab) if needed. nginx is what actually binds
# PORT -- the Spring Boot app itself always listens on the fixed
# JODCONVERTER_APP_PORT and is only reachable through the nginx proxy.
ENV PORT=8080 \
    JODCONVERTER_APP_PORT=8088 \
    JODCONVERTER_LOCAL_PORT_NUMBERS=2002,2003 \
    JODCONVERTER_LOCAL_WORKING_DIR=/tmp \
    SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE=20MB \
    SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE=20MB \
    NGINX_CLIENT_MAX_BODY_SIZE=25m \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:InitialRAMPercentage=50" \
    API_KEYS=""

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/railway-entrypoint.sh"]
