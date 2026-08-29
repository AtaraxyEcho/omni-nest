#!/bin/sh
set -eu

if [ "${OMNINEST_HTTPS_ENABLED:-false}" != "true" ]; then
    exit 0
fi

public_host="${OMNINEST_PUBLIC_HOST:-localhost}"
http_port="${OMNINEST_PUBLIC_HTTP_PORT:-80}"
https_port="${OMNINEST_PUBLIC_HTTPS_PORT:-443}"
minio_port="${OMNINEST_PUBLIC_MINIO_PORT:-9000}"
allowed_origins="${OMNINEST_SECURITY_ALLOWED_ORIGINS:-}"
setup_web_base_url="${OMNINEST_SETUP_WEB_BASE_URL:-}"
minio_public_endpoint="${OMNINEST_MINIO_PUBLIC_ENDPOINT:-}"

case "$http_port" in
    ''|*[!0-9]*)
        echo "OMNINEST_PUBLIC_HTTP_PORT 必须是有效端口" >&2
        exit 1
        ;;
esac
if [ "$http_port" -lt 1 ] || [ "$http_port" -gt 65535 ]; then
    echo "OMNINEST_PUBLIC_HTTP_PORT 必须位于 1 到 65535" >&2
    exit 1
fi
if [ "$http_port" != "80" ]; then
    echo "HTTPS 模式使用 HTTP-01 时，OMNINEST_PUBLIC_HTTP_PORT 必须为 80" >&2
    exit 1
fi

if [ "$https_port" = "443" ]; then
    public_origin="https://${public_host}"
else
    public_origin="https://${public_host}:${https_port}"
fi
minio_origin="https://${public_host}:${minio_port}"

origin_configured=false
previous_ifs="$IFS"
IFS=','
for origin in $allowed_origins; do
    trimmed_origin="$(printf '%s' "$origin" | tr -d '[:space:]')"
    if [ "$trimmed_origin" = "$public_origin" ]; then
        origin_configured=true
        break
    fi
done
IFS="$previous_ifs"

if [ "$origin_configured" != "true" ]; then
    echo "HTTPS 模式要求 OMNINEST_SECURITY_ALLOWED_ORIGINS 包含 ${public_origin}" >&2
    exit 1
fi
if [ "$setup_web_base_url" != "$public_origin" ]; then
    echo "HTTPS 模式要求 OMNINEST_SETUP_WEB_BASE_URL=${public_origin}" >&2
    exit 1
fi
if [ "$minio_public_endpoint" != "$minio_origin" ]; then
    echo "HTTPS 模式要求 OMNINEST_MINIO_PUBLIC_ENDPOINT=${minio_origin}" >&2
    exit 1
fi
