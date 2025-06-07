#!/bin/bash

# Synology DSM Installer for Pelican Wings
# assumes: root permissions, Entware installed (opkg), docker installed via Package Center

print_success() { echo -e "\e[32m$1\e[0m"; }
print_error() { echo -e "\e[31m$1\e[0m"; }

# check for whiptail (via Entware)
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

# docker & docker Compose assumed installed via Synology Package Center

# download Wings binary
if [ ! -f /usr/local/bin/wings ]; then
    print_success "Downloading Wings binary..."
    mkdir -p /etc/pelican
    curl -L -o /usr/local/bin/wings "https://github.com/pelican-dev/wings/releases/latest/download/wings_linux_$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")"
    chmod u+x /usr/local/bin/wings
    if [ $? -ne 0 ]; then print_error "Download failed."; exit 1; fi
    print_success "Wings downloaded."
else
    print_success "Wings already installed."
fi

# configure Wings
if [ ! -f /etc/pelican/config.yml ]; then
    print_success "Configuring Wings..."
    whiptail --msgbox "Go to your Panel admin, create a Node, and paste config.yml into /etc/pelican." 15 60
    nano /etc/pelican/config.yml
    if [ $? -ne 0 ]; then print_error "Editing config failed."; exit 1; fi
    print_success "Wings configured."
else
    print_success "Wings already configured."
fi

# systemd is not native on Synology DSM, use synoservice (or let user run manually)
print_success "Synology DSM does NOT use systemd. To run Wings, add it as a scheduled task or run it manually with:"
echo "    /usr/local/bin/wings"
print_success "Wings installation for Synology DSM ready!"
