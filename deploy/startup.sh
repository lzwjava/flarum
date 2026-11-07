#!/bin/bash
set -euxo pipefail

# --- Install Docker + compose plugin ---
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y docker.io docker-compose-v2 curl
systemctl enable --now docker

# --- Docker credential helper for private Artifact Registry pulls ---
curl -fsSL -o /tmp/docker-credential-gcr.tar.gz https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v2.2.1/docker-credential-gcr_linux_amd64-2.2.1.tar.gz
tar -xzf /tmp/docker-credential-gcr.tar.gz -C /usr/local/bin docker-credential-gcr
chmod +x /usr/local/bin/docker-credential-gcr
/usr/local/bin/docker-credential-gcr configure-docker
# configure-docker only registers gcr.io domains; add Artifact Registry pkg.dev
python3 - <<'PY'
import json, os
for home in (os.path.expanduser('~'), '/root'):
    p = home + '/.docker/config.json'
    if not os.path.isfile(p):
        continue
    d = json.load(open(p))
    d.setdefault('credHelpers', {})['us-central1-docker.pkg.dev'] = 'gcr'
    json.dump(d, open(p, 'w'))
    print('registered pkg.dev credHelper in', p)
PY

# --- Flarum deployment files ---
mkdir -p /opt/flarum
cd /opt/flarum

cat > docker-compose.yml <<'COMPOSE'
services:
  db:
    image: mysql:8.0
    restart: unless-stopped
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --innodb-buffer-pool-size=128M
    environment:
      MYSQL_DATABASE: flarum
      MYSQL_USER: flarum
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    volumes:
      - mysql-data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "127.0.0.1", "-uflarum", "-p${MYSQL_PASSWORD}"]
      interval: 10s
      timeout: 5s
      retries: 12
      start_period: 60s

  app:
    image: us-central1-docker.pkg.dev/graphite-ally-445108-k3/flarum/flarum:latest
    restart: unless-stopped
    environment:
      DB_HOST: db
      DB_PORT: "3306"
      DB_DATABASE: flarum
      DB_USERNAME: flarum
      DB_PASSWORD: ${MYSQL_PASSWORD}
      FLARUM_URL: ${FLARUM_URL}
      FLARUM_FORUM_TITLE: ${FLARUM_FORUM_TITLE}
      FLARUM_ADMIN_USER: admin
      FLARUM_ADMIN_PASSWORD: ${FLARUM_ADMIN_PASSWORD}
      FLARUM_ADMIN_EMAIL: admin@example.com
    volumes:
      - app-www:/var/www/html
      - flarum-config:/flarum-config
      - flarum-storage:/var/www/html/storage
    depends_on:
      db:
        condition: service_healthy

  web:
    image: nginx:1.27-alpine
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - app-www:/var/www/html:ro
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
    depends_on:
      - app

volumes:
  app-www:
  flarum-config:
  flarum-storage:
  mysql-data:
COMPOSE

cat > nginx.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    root /var/www/html/public;
    index index.php;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass app:9000;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~* \.(?:manifest|appcache|html?|xml|json)$ {
        add_header Cache-Control "max-age=0";
    }

    location ~* \.(?:rss|atom)$ {
        add_header Cache-Control "max-age=3600";
    }

    location ~* \.(?:jpg|jpeg|gif|png|webp|ico|cur|gz|svg|mp4|ogg|ogv|webm|htc)$ {
        add_header Cache-Control "max-age=2592000";
        access_log off;
    }

    location ~* \.(?:css|js)$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
    }

    location ~* \.(?:ttf|ttc|otf|eot|woff|woff2)$ {
        add_header Cache-Control "max-age=2592000";
        access_log off;
    }

    gzip on;
    gzip_comp_level 5;
    gzip_min_length 256;
    gzip_proxied any;
    gzip_vary on;
    gzip_types
        application/atom+xml
        application/javascript
        application/json
        application/ld+json
        application/manifest+json
        application/rss+xml
        application/vnd.geo+json
        application/vnd.ms-fontobject
        application/x-font-ttf
        application/x-web-app-manifest+json
        application/xhtml+xml
        application/xml
        font/opentype
        image/svg+xml
        image/x-icon
        text/cache-manifest
        text/css
        text/javascript
        text/plain
        text/vcard
        text/vnd.rim.location.xloc
        text/vtt
        text/x-component
        text/x-cross-domain-policy;
}
NGINX

cat > .env <<ENV
MYSQL_PASSWORD=__MYSQL_PASSWORD__
MYSQL_ROOT_PASSWORD=__MYSQL_ROOT_PASSWORD__
FLARUM_URL=http://__FLARUM_IP__
FLARUM_FORUM_TITLE=Flarum Forum
FLARUM_ADMIN_PASSWORD=__FLARUM_ADMIN_PASSWORD__
ENV

# --- Start the stack ---
docker compose up -d --pull missing

# -- Restart policy to make sure it survives reboots ---
