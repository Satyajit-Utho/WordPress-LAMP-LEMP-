#!/bin/bash

# LEMP WordPress Auto Installer for Debian 11/12
# Author: Satyajit Barik
# Usage: bash deploy-wordpress-lemp.sh

### CONFIGURATION ###
DB_NAME="wordpress"
DB_USER="wpuser"
DB_PASS="wp_password"
DB_ROOT_PASS="root_password"
WP_DIR="/var/www/html"
PHP_VERSION="8.2"  # Change if needed (e.g., 8.1 or 8.3)
#####################

echo "[+] Updating system..."
apt update && apt upgrade -y

echo "[+] Installing required packages..."
apt install -y nginx mariadb-server php${PHP_VERSION}-fpm php${PHP_VERSION}-mysql php${PHP_VERSION}-xml php${PHP_VERSION}-cli php${PHP_VERSION}-curl php${PHP_VERSION}-mbstring php${PHP_VERSION}-zip php${PHP_VERSION}-gd php${PHP_VERSION}-soap unzip wget curl

echo "[+] Starting and enabling services..."
systemctl enable --now nginx mariadb php${PHP_VERSION}-fpm

echo "[+] Securing MariaDB..."
mysql -e "UPDATE mysql.user SET Password=PASSWORD('${DB_ROOT_PASS}') WHERE User='root';"
mysql -e "DELETE FROM mysql.user WHERE User='';"
mysql -e "DROP DATABASE IF EXISTS test;"
mysql -e "FLUSH PRIVILEGES;"

echo "[+] Creating WordPress DB and user..."
mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE DATABASE ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -u root -p"${DB_ROOT_PASS}" -e "CREATE USER '${DB_USER}'@'localhost' IDENTIFIED BY '${DB_PASS}';"
mysql -u root -p"${DB_ROOT_PASS}" -e "GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'localhost';"
mysql -u root -p"${DB_ROOT_PASS}" -e "FLUSH PRIVILEGES;"

echo "[+] Downloading and setting up WordPress..."
wget -q https://wordpress.org/latest.zip
unzip -q latest.zip
rm -rf ${WP_DIR}/*
cp -r wordpress/* ${WP_DIR}/
rm -rf wordpress latest.zip

echo "[+] Setting permissions..."
chown -R www-data:www-data ${WP_DIR}
chmod -R 755 ${WP_DIR}

echo "[+] Creating wp-config.php..."
cp ${WP_DIR}/wp-config-sample.php ${WP_DIR}/wp-config.php
sed -i "s/database_name_here/${DB_NAME}/" ${WP_DIR}/wp-config.php
sed -i "s/username_here/${DB_USER}/" ${WP_DIR}/wp-config.php
sed -i "s/password_here/${DB_PASS}/" ${WP_DIR}/wp-config.php

echo "[+] Configuring Nginx..."
cat > /etc/nginx/sites-available/wordpress <<EOF
server {
    listen 80;
    server_name _;

    root ${WP_DIR};
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php${PHP_VERSION}-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

ln -sf /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/wordpress
rm -f /etc/nginx/sites-enabled/default

echo "[+] Testing and restarting Nginx..."
nginx -t && systemctl restart nginx

echo ""
echo "✅ WordPress LEMP stack installed successfully!"
echo "🌐 Visit your server IP to complete the WordPress setup."
