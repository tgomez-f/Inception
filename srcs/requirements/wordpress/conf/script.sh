#!/bin/bash

# Lecture du secret en variable pour éviter les problèmes avec les caractères spéciaux
DB_PASSWORD=$(cat /run/secrets/db_password)

# Attend que MariaDB soit complètement opérationnel.
# mysql -e "SELECT 1" vérifie une connexion complète (auth + base + requête),
# contrairement à mysqladmin ping qui teste seulement le port TCP et peut
# réussir pendant la phase d'init de MariaDB (avant son restart interne).
until mysql -h mariadb -u "$SQL_USER" -p"$DB_PASSWORD" "$SQL_DATABASE" \
    -e "SELECT 1;" > /dev/null 2>&1; do
    echo "Waiting for MariaDB..."
    sleep 1
done

cd /var/www/wordpress

# Crée wp-config.php seulement s'il est absent.
# Sans ce guard, wp config create échoue au redémarrage du container
# car le fichier existe déjà, ce qui stoppe le script.
if [ ! -f wp-config.php ]; then
    wp config create \
        --dbname=$SQL_DATABASE \
        --dbuser=$SQL_USER \
        --dbpass=$(cat /run/secrets/db_password) \
        --dbhost=$SQL_HOST \
        --allow-root
fi

# Installe WordPress seulement si ce n'est pas déjà fait.
# Même raison : wp core install échoue si WordPress est déjà installé en base.
if ! wp core is-installed --allow-root 2>/dev/null; then
    wp core install \
        --url=$DOMAIN_NAME \
        --title=$SITE_NAME \
        --admin_user=$WP_ADMIN_USER \
        --admin_password=$(cat /run/secrets/wp_admin_password) \
        --admin_email=$WP_ADMIN_EMAIL \
        --allow-root
fi

# Crée l'utilisateur secondaire seulement s'il n'existe pas déjà.
if ! wp user get "$WP_USER" --allow-root 2>/dev/null; then
    wp user create \
        $WP_USER \
        $WP_USER_EMAIL \
        --user_pass=$(cat /run/secrets/wp_user_password) \
        --allow-root
fi

# Lance php-fpm en foreground (PID 1) — pas de boucle
exec php-fpm8.2 -F