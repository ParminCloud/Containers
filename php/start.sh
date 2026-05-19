#!/usr/bin/env bash

case ${START_RUNTIME} in
  fpm)
    exec php-fpm
    ;;

  cli)
    exec php -a
    ;;

  apache)
    for f in /etc/apache2/sites-available/*.conf; do
      [ -f "$f" ] && ! grep -q "${DOCUMENT_ROOT}" "$f" && sed -ri -e "s!/var/www/html!${DOCUMENT_ROOT}!g" "$f"
    done

    for f in /etc/apache2/apache2.conf /etc/apache2/conf-available/*.conf; do
      [ -f "$f" ] && ! grep -q "${DOCUMENT_ROOT}" "$f" && sed -ri -e "s!/var/www/!${DOCUMENT_ROOT}!g" "$f"
    done
    export APACHE_ENVVARS=/etc/apache2/envvars
    . "$APACHE_ENVVARS"
    for dir in "$APACHE_LOCK_DIR" "$APACHE_RUN_DIR" "$APACHE_LOG_DIR" "$APACHE_RUN_DIR/socks"; do
      rm -rvf "$dir"
      mkdir -p "$dir"
      chown "$APACHE_RUN_USER:$APACHE_RUN_GROUP" "$dir"
      chmod 1777 "$dir"
    done
    ln -sfT /dev/stderr "$APACHE_LOG_DIR/error.log"
    ln -sfT /dev/stdout "$APACHE_LOG_DIR/access.log"
    ln -sfT /dev/stdout "$APACHE_LOG_DIR/other_vhosts_access.log"
    rm -f /var/run/apache2/apache2.pid
    a2dismod mpm_event
    a2enmod mpm_prefork
    a2enconf docker-php
    exec apache2 -DFOREGROUND
    ;;

  nginx)
    if [ -f /etc/nginx/nginx.conf ] && ! grep -q "${DOCUMENT_ROOT}" /etc/nginx/nginx.conf; then
      sed -ri -e "s!/var/www/html!${DOCUMENT_ROOT}!g" /etc/nginx/nginx.conf
    fi
    exec /usr/bin/supervisord -c /opt/parmincloud/php/nginx-supervisord.conf
    ;;

  *)
    exec "$@"
    ;;
esac

