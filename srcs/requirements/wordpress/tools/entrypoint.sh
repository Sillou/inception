#!/bin/sh

DB_PASSWORD="$(cat /run/secrets/db_password )"
WP_ADMIN_PASSWORD="$(cat /run/secrets/wp_admin_password)"
WP_USER_PASSWORD="$(cat /run/secrets/wp_user_password)"

if [ ! -f /var/www/html/wp-config.php ]; then
	wp core download --allow-root --path=/var/www/html
	wp config create --allow-root --path=/var/www/html \
		--dbname="$MYSQL_DATABASE" \
		--dbuser="$MYSQL_USER" \
		--dbpass="$DB_PASSWORD" \
		--dbhost=mariadb
fi

if ! wp core is-installed --allow-root --path=/var/www/html; then
	wp core install --allow-root --path=/var/www/html \
		--url="https://$DOMAIN_NAME" \
		--title="$WP_TITLE" \
		--admin_user="$WP_ADMIN_USER" \
		--admin_password="$WP_ADMIN_PASSWORD" \
		--admin_email="$WP_ADMIN_EMAIL" \
		--skip-email
	wp user create "$WP_USER" "$WP_USER_EMAIL" --allow-root --path=/var/www/html \
		--role=author \
		--user_pass="$WP_USER_PASSWORD"
fi

exec "$@"
