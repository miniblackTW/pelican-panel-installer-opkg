#!/bin/bash

# Synology DSM Installer for Pelican Panel
# this script is adapted for Synology NAS (DSM 7.x+), which does not support apt
# assumes: root permissions, Entware installed (for opkg), DSM 7.x+, PHP8 & MariaDB installed via Package Center

print_success() { echo -e "\e[32m$1\e[0m"; }
print_error() { echo -e "\e[31m$1\e[0m"; }

# check for whiptail (via Entware)
if ! command -v whiptail &> /dev/null; then
    print_error "whiptail not found. Installing via Entware (opkg)..."
    if ! command -v opkg &> /dev/null; then
        print_error "Entware/opkg is not installed. Please install Entware via Synology Package Center or manually before continuing."
        exit 1
    fi
    opkg install whiptail
    if [ $? -ne 0 ]; then print_error "Failed to install whiptail."; exit 1; fi
    print_success "whiptail installed."
fi

# choose webserver (only NginX/Apache if installed via Package Center)
WEBSERVER=$(whiptail --title "Select Webserver" --menu "Choose your webserver" 15 60 2 \
"NGINX" "" \
"Apache" "" 3>&1 1>&2 2>&3)

# PHP and MariaDB should be installed via Synology Package Center beforehand
print_success "Assuming PHP 8.x and MariaDB are installed via Package Center. If not, please install them before running this script."

# composer install
if ! command -v composer &> /dev/null; then
    print_success "Installing composer..."
    curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer
    if [ $? -ne 0 ]; then print_error "Composer install failed."; exit 1; fi
    print_success "Composer installed."
fi

# create Pelican directory and download files
if [ ! -d /volume1/web/pelican ]; then
    print_success "Creating directory and downloading panel files..."
    mkdir -p /volume1/web/pelican
    cd /volume1/web/pelican
    curl -Lo panel.tar.gz https://github.com/pelican-dev/panel/releases/latest/download/panel.tar.gz
    tar -xzvf panel.tar.gz
    chmod -R 755 storage/* bootstrap/cache/
    if [ $? -ne 0 ]; then print_error "Download or extraction failed."; exit 1; fi
    print_success "Panel files ready."
else
    print_success "Directory exists, skipping download."
fi

# composer dependencies
if [ ! -d /volume1/web/pelican/vendor ]; then
    print_success "Installing composer dependencies..."
    cd /volume1/web/pelican
    composer install --no-dev --optimize-autoloader
    if [ $? -ne 0 ]; then print_error "Composer install failed."; exit 1; fi
    print_success "Composer dependencies installed."
else
    print_success "Composer dependencies already present."
fi

# environment setup
if [ ! -f /volume1/web/pelican/.env ]; then
    print_success "Configuring environment..."
    cd /volume1/web/pelican
    php artisan p:environment:setup
    php artisan p:environment:database
    if [ $? -ne 0 ]; then print_error "Environment setup failed."; exit 1; fi
    print_success "Environment configured."
else
    print_success "Environment already configured."
fi

# MariaDB (MySQL) setup
MYSQL_ROOT_PASSWORD=$(whiptail --passwordbox "Enter MariaDB root password:" 10 60 3>&1 1>&2 2>&3)
MYSQL_PELICAN_PASSWORD=$(whiptail --passwordbox "Password for 'pelican' user:" 10 60 3>&1 1>&2 2>&3)
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE USER IF NOT EXISTS 'pelican'@'localhost' IDENTIFIED BY '$MYSQL_PELICAN_PASSWORD';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "CREATE DATABASE IF NOT EXISTS panel;"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "GRANT ALL PRIVILEGES ON panel.* TO 'pelican'@'localhost';"
mysql -u root -p"$MYSQL_ROOT_PASSWORD" -e "FLUSH PRIVILEGES;"
if [ $? -ne 0 ]; then print_error "Failed to set up MySQL user/database."; exit 1; fi
print_success "MySQL user/database ready."

# Database migration/seed
if [ ! -f /volume1/web/pelican/database/initialized ]; then
    print_success "Initializing database..."
    cd /volume1/web/pelican
    php artisan migrate --seed --force
    if [ $? -ne 0 ]; then print_error "DB migration failed."; exit 1; fi
    touch /volume1/web/pelican/database/initialized
    print_success "Database initialized."
else
    print_success "Database already initialized."
fi

# admin user setup
if (whiptail --title "Admin User Setup" --yesno "Do you want to create an admin user?" 10 60); then
    php artisan p:user:make
    if [ $? -ne 0 ]; then print_error "Failed to create admin user."; exit 1; fi
    print_success "Admin user created."
fi

# mail setup
if (whiptail --title "Mail Setup" --yesno "Do you want to set up mail?" 10 60); then
    php artisan p:environment:mail
    if [ $? -ne 0 ]; then print_error "Mail setup failed."; exit 1; fi
    print_success "Mail configured."
fi

# set permissions (Synology web server user is usually 'http')
print_success "Setting permissions for DSM web dir (user http)..."
chown -R http:http /volume1/web/pelican
if [ $? -ne 0 ]; then print_error "Set permissions failed."; exit 1; fi
print_success "Permissions set."

print_success "Pelican Panel installation completed for Synology DSM!"
