#!/bin/bash

until mysqladmin ping -h mariadb --silent; do
	sleep 1
done

cd /var/www/wordpress

wp config create \
    --dbname=$SQL_DATABASE \
    --dbuser=$SQL_USER \
    --dbpass=$(cat /run/secrets/db_password) \
    --dbhost=$SQL_HOST \
    --allow-root
	
wp core install \
	--url=$DOMAIN_NAME \
	--title=$SITE_NAME \
	--admin_user=$WP_ADMIN_USER \
	--admin_password=$(cat /run/secrets/wp_admin_password) \
	--admin_email=$WP_ADMIN_EMAIL \
	--allow-root

wp user create \
	$WP_USER \
	$WP_USER_EMAIL \
	--user_pass=$(cat /run/secrets/wp_user_password) \
	--allow-root

exec php-fpm7.4 -F