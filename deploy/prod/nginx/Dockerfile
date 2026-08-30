FROM debian:bookworm-slim AS web-builder

ARG FLUTTER_VERSION=3.44.8
ARG FLUTTER_SHA256=672089e001571a9fbb209a495c583580c0c6c73ef98999264ba07fa93ace332d

RUN apt-get update \
    && apt-get install --yes --no-install-recommends ca-certificates curl git unzip xz-utils \
    && rm -rf /var/lib/apt/lists/*

RUN curl --fail --location --silent --show-error \
        "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
        --output /tmp/flutter.tar.xz \
    && echo "${FLUTTER_SHA256}  /tmp/flutter.tar.xz" | sha256sum --check --strict \
    && tar --extract --xz --file /tmp/flutter.tar.xz --directory /opt \
    && rm /tmp/flutter.tar.xz \
    && git config --global --add safe.directory /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /workspace/frontend

COPY frontend/pubspec.yaml frontend/pubspec.lock ./
COPY frontend/ ./
RUN flutter config --no-analytics --enable-web \
    && flutter pub get \
    && flutter build web --release --no-pub

FROM nginx:1.28-alpine

RUN apk add --no-cache gettext

COPY --from=web-builder /workspace/frontend/build/web /usr/share/nginx/html
COPY deploy/prod/nginx/templates/ /opt/omninest/templates/
COPY deploy/prod/nginx/validate-config.sh /opt/omninest/validate-config.sh
COPY deploy/prod/nginx/render-config.sh /opt/omninest/render-config.sh
COPY deploy/prod/nginx/watch-certificates.sh /opt/omninest/watch-certificates.sh
COPY deploy/prod/nginx/entrypoint.sh /opt/omninest/entrypoint.sh

RUN chmod 0755 /opt/omninest/*.sh \
    && rm -f /etc/nginx/conf.d/default.conf

ENTRYPOINT ["/opt/omninest/entrypoint.sh"]
CMD ["nginx", "-g", "daemon off;"]
