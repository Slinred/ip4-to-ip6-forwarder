# Use a lightweight base image
FROM alpine:latest

# Install 6tunnel
RUN apk add --no-cache 6tunnel \
    && apk add --no-cache perl 

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT [ "sh", "-c", "/entrypoint.sh" ]
