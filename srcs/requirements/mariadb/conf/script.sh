#!/bin/bash

# Lance MariaDB en arrière-plan (grace a '&') avec le user=mysql pour l'init
mysqld_safe --user=mysql &

# Attend que MariaDB soit bien init
until mysqladmin --socket=/run/mysqld/mysqld.sock ping --silent 2>/dev/null; do
    echo "MariaDB is booting..."
    sleep 1
done

# Config DB
mysql --socket=/run/mysqld/mysqld.sock -u root <<EOF
CREATE DATABASE IF NOT EXISTS ${SQL_DATABASE};
CREATE USER IF NOT EXISTS '${SQL_USER}'@'%' IDENTIFIED BY '$(cat /run/secrets/db_password)';
GRANT ALL PRIVILEGES ON ${SQL_DATABASE}.* TO '${SQL_USER}'@'%';
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$(cat /run/secrets/db_root_password)';
EOF
# '%':autorisé depuis n'importe quelle IP
# ligne ALTER USER: change le mot de passe du user root local

# Shutdown propre
mysqladmin --socket=/run/mysqld/mysqld.sock \
    -u root -p"$(cat /run/secrets/db_root_password)" shutdown

# Foreground — PID 1, pas de boucle
exec mysqld_safe --user=mysql