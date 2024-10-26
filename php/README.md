# All in One PHP Container

## Variants

* apache: Based on Apache and serves your code using Apache2
* nginx: Based on PHP FPM and NGINX
* fpm: Based on PHP FPM can be used as FactCGI server
* cli: Contains no builtin webserver (Swoole is pre-installed)

## ENVs

* `DOCUMENT_ROOT`: Defaults to `/var/www/html` and sets root dir of servers (works on apache and nginx)
    > In laravel you might set it to `/var/www/html/public`
