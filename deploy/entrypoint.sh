#!/bin/bash
set -e

APPDIR=/var/www/html
CONFIG="$APPDIR/config.php"
PERSIST=/flarum-config/config.php

echo "[flarum] starting entrypoint"

if [ -f "$PERSIST" ]; then
    echo "[flarum] restoring persistent config.php"
    cp "$PERSIST" "$CONFIG"
else
    echo "[flarum] no persistent config found - running first-time install"
    envsubst < /opt/deploy/install-config.json.tpl > /tmp/install.json
    cd "$APPDIR"
    # NOTE: do not pass -c; the option is joined to the base path,
    # so an absolute path would be doubled (/var/www/html//var/www/html/...)
    php flarum install -f /tmp/install.json
    mkdir -p /flarum-config
    cp "$CONFIG" "$PERSIST"
    echo "[flarum] install complete"
fi

# Keep runtime-writable paths writable by the FPM user (compiled assets are
# written into public/assets at runtime - e.g. js/css compiled by the frontend)
mkdir -p "$APPDIR/storage"
chown -R www-data:www-data "$APPDIR/storage" "$APPDIR/public/assets" 2>/dev/null || true

exec "$@"
