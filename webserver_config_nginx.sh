#!/bin/bash

# NginX config helper for Pelican Panel on Synology DSM
# Assumes NginX installed via Package Center, web root is /volume1/web

print_success() { echo -e "\e[32m$1\e[0m"; }
print_error() { echo -e "\e[31m$1\e[0m"; }

# check for whiptail
if ! command -v whiptail &> /dev/null; then
    print_error "whiptail not found. Installing via Entware (opkg)..."
    if ! command -v opkg &> /dev/null; then
        print_error "Entware/opkg is not installed. Please install Entware before continuing."
        exit 1
    fi
    opkg update && opkg install whiptail
    if [ $? -ne 0 ]; then print_error "Failed to install whiptail."; exit 1; fi
    print_success "whiptail installed."
fi

DOMAIN=$(whiptail --inputbox "Enter your domain or IP address (Note: IPs cannot be used with SSL):" 10 60 3>&1 1>&2 2>&3)

# NginX main config path for Synology
NGINX_CONF_DIR="/usr/local/etc/nginx/conf.d"
NGINX_CONF="$NGINX_CONF_DIR/pelican.conf"

print_success "Creating NGINX config for Pelican..."
cat <<EOL > "$NGINX_CONF"
server {
    listen 80;
    server_name $DOMAIN;

    root /volume1/web/pelican/public;
    index index.html index.htm index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    access_log off;
    error_log  /var/log/nginx/pelican.app-error.log error;

    client_max_body_size 100m;
    client_body_timeout 120s;

    sendfile off;

    location ~ \.php$ {
        fastcgi_split_path_info ^(.+\.php)(/.+)$;
        fastcgi_pass unix:/run/php-fpm.sock;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param PHP_VALUE "upload_max_filesize = 100M \n post_max_size=100M";
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param HTTP_PROXY "";
        fastcgi_intercept_errors off;
        fastcgi_buffer_size 16k;
        fastcgi_buffers 4 16k;
        fastcgi_connect_timeout 300;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOL

if [ $? -ne 0 ]; then print_error "Failed to create NGINX config."; exit 1; fi
print_success "NGINX config created at $NGINX_CONF"

print_success "Restarting NGINX via Synology DSM..."
synosystemctl restart nginx

print_success "NGINX configuration for Pelican Panel on Synology DSM completed successfully!"
