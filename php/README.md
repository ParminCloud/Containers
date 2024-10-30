# All in One PHP Container

![GitHub Actions Workflow Status](https://img.shields.io/github/actions/workflow/status/ParminCloud/Containers/php.yaml) ![PHP](https://img.shields.io/badge/PHP-777BB4?style=for-the-badge&logo=php&logoColor=white)

Mostly used PHP extentions are pre installed and Binaries are stripped and multi-staged making this image to be smaller in size by about 1/3

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

## Example Usage

Containerfile/Dockerfile:

```containerfile
FROM ghcr.io/parmincloud/containers/php:php8.1-nginx

COPY composer.* /var/www/html/
COPY package.* /var/www/html/
RUN yarn install # npm is also available
RUN composer install --no-scripts --no-autoloader --no-interaction --prefer-dist

COPY . .
RUN composer dump-autoload --optimize
```

## Known Issues

* Multi Platform builds are disabled due to [this issue](https://github.com/ParminCloud/Containers/issues/1)


## FAQ

* Why gRPC (and OTLP gRPC) Clients are not working in some environments?  
  Enable froking support for gRPC By setting these ENVs (According to https://github.com/grpc/grpc/blob/master/doc%2Ffork_support.md) 
  GRPC_ENABLE_FORK_SUPPORT=true  
  GRPC_POLL_STRATEGY=epoll1  