
#
# Composer Dependencies
#
FROM composer:2 AS composer
WORKDIR /var/www/html
COPY composer.json composer.lock ./
ARG DEBUG=off
RUN composer install --no-interaction --no-plugins --no-scripts --prefer-dist --ignore-platform-reqs $(if [ "$DEBUG" = "off" ]; then echo "--no-dev"; fi)

#
# Runtime
#
FROM serversideup/php:8.4-fpm-nginx

# Environment variables
ENV SSL_MODE=off
ENV AUTORUN_ENABLED=true
ENV AUTORUN_LARAVEL_MIGRATION_ISOLATION=true

# Install PHP extensions
USER root
RUN install-php-extensions bcmath calendar exif gd intl pdo_pgsql
COPY .docker/zzz-custom-php.ini /usr/local/etc/php/conf.d/

# Switch to www-data user for security
USER www-data

# Set working directory
WORKDIR /var/www/html

# Copy application files and installed dependencies
COPY --from=composer --chown=www-data:www-data /var/www/html ./
COPY --chown=www-data:www-data . ./

# Copy custom NGINX config (to disable IPv6)
COPY .docker/nginx/laravel.conf /etc/nginx/sites-enabled/default.conf

COPY .docker/nginx-patched/http.conf /etc/nginx/site-opts.d/http.conf
COPY .docker/nginx-patched/http.conf.template /etc/nginx/site-opts.d/http.conf.template
COPY .docker/nginx-patched/ssl-full /etc/nginx/sites-available/ssl-full

# Run necessary commands
RUN composer dump-autoload \
    && composer clear-cache \
    && php artisan livewire:publish --assets \
    && chmod 660 secrets/oauth/oauth-private.key secrets/oauth/oauth-public.key
