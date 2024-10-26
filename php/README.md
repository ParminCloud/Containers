# All in One PHP Container

## Variants

* apache: Based on Apache and serves your code using Apache2
* nginx: Based on PHP FPM and NGINX
* fpm: Based on PHP FPM can be used as FactCGI server
* cli: Contains no builtin webserver (Swoole is pre-installed)

## Avaialable Images

* ghcr.io/parmincloud/containers/php:php8.1-nginx
* ghcr.io/parmincloud/containers/php:php8.1-apache
* ghcr.io/parmincloud/containers/php:php8.1-fpm
* ghcr.io/parmincloud/containers/php:php8.1-cli

> Replace 8.1 with your PHP Version (8.1, 8.2 and 8.3 is available)

## ENVs

* `DOCUMENT_ROOT`: Defaults to `/var/www/html` and sets root dir of servers (works on apache and nginx)
    > In laravel you might set it to `/var/www/html/public`
