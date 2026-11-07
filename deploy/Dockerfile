FROM php:8.4-fpm

# Install PHP extensions required by Flarum and tools for the install step
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        git unzip gettext-base curl \
        libzip-dev libpng-dev libjpeg-dev libwebp-dev libfreetype6-dev \
        libicu-dev libonig-dev; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install gd pdo_mysql intl mbstring opcache zip exif fileinfo; \
    docker-php-ext-enable opcache; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Application code (vendor/config are excluded via .dockerignore)
COPY . /var/www/html
RUN composer install --no-dev --no-interaction --prefer-dist --optimize-autoloader

# Deployment helpers (used by the entrypoint for first-run install)
COPY deploy/entrypoint.sh /opt/deploy/entrypoint.sh
COPY deploy/install-config.json.tpl /opt/deploy/install-config.json.tpl
RUN chmod +x /opt/deploy/entrypoint.sh

ENTRYPOINT ["/opt/deploy/entrypoint.sh"]
CMD ["php-fpm"]
