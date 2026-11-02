#!/bin/sh

DB_PASSWORD="$(cat /run/secrets/db_password )"
DB_ROOTPASSWORD="$(cat /run/secrets/db_root_password )"

mariadbd --user=mysql --bootstrap << EOF
FLUSH PRIVILEGES;
CREATE DATABASE IF NOT EXISTS ${MYSQL_DATABASE};
CREATE USER IF NOT EXISTS '${MYSQL_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${MYSQL_DATABASE}.* TO '${MYSQL_USER}'@'%';
ALTER USER 'root'@'localhost' IDENTIFIED BY '${DB_ROOTPASSWORD}';
FLUSH PRIVILEGES;
EOF



exec "$@"
