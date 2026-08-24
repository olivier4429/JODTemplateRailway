# Railway template for JODConverter (document conversion via LibreOffice)
#
# This builds on top of the official JODConverter "rest" sample image, which
# bundles LibreOffice + the jodconverter-spring-boot-starter REST sample app.
# See: https://github.com/jodconverter/docker-image-jodconverter-examples
#
# The only thing this Dockerfile adds is a thin entrypoint wrapper so the
# app listens on the dynamic $PORT that Railway injects at runtime, plus
# a few sane default environment variables.
ARG JODCONVERTER_IMAGE_TAG=rest
FROM ghcr.io/jodconverter/jodconverter-examples:${JODCONVERTER_IMAGE_TAG}

# Sensible defaults; all of these can be overridden as Railway service
# variables without rebuilding the image (Spring Boot relaxed binding
# maps SCREAMING_SNAKE_CASE env vars to their dotted property names).
ENV SERVER_PORT=8080 \
    JODCONVERTER_LOCAL_PORT_NUMBERS=2002,2003 \
    JODCONVERTER_LOCAL_WORKING_DIR=/tmp \
    SPRING_SERVLET_MULTIPART_MAX_FILE_SIZE=20MB \
    SPRING_SERVLET_MULTIPART_MAX_REQUEST_SIZE=20MB \
    JAVA_TOOL_OPTIONS="-XX:MaxRAMPercentage=75 -XX:InitialRAMPercentage=50"

COPY railway-entrypoint.sh /railway-entrypoint.sh
RUN chmod +x /railway-entrypoint.sh

EXPOSE 8080

ENTRYPOINT ["/railway-entrypoint.sh"]
