#!/bin/env bash

# Detect Distribution
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=$ID
else
    echo "Distribution not supported by this script."
    exit 1
fi

# Check for root privileges
if [[ $EUID -ne 0 ]]; then
    echo "Please run this script with sudo."
    exit 1
fi

# Prompt for PHP version or use latest
echo "Enter PHP version (e.g., 7.4, 8.0, 8.1) or press Enter for latest:"
read PHP_VERSION

# Default to latest PHP version if none specified
if [[ -z "$PHP_VERSION" ]]; then
    PHP_VERSION="8.3"
    echo "Using latest PHP version: $PHP_VERSION"
fi

# Function to install LAMP and switch PHP on Ubuntu
install_ubuntu() {
    echo "Updating package lists..."
    sudo apt-get update

    echo "Adding Ondrej PHP repository..."
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update

    echo "Installing Apache..."
    sudo apt-get install -y apache2

    echo "Installing MariaDB..."
    sudo apt-get install -y mariadb-server

    echo "Installing PHP and necessary extensions..."
    sudo apt-get install -y php"$PHP_VERSION" libapache2-mod-php"$PHP_VERSION"  php"$PHP_VERSION"-{bz2,curl,intl,mysql,readline,xml,common,cli}

    echo "Installing phpMyAdmin..."
    sudo apt-get install -y phpmyadmin

    echo "Disabling current PHP version..."
    sudo a2dismod php*

    echo "Enabling PHP $PHP_VERSION for Apache..."
    sudo a2enmod php$PHP_VERSION

    echo "Restarting Apache..."
    sudo systemctl restart apache2

    echo "Securing MariaDB installation..."
    sudo mysql_secure_installation

    echo "Setting PHP CLI version with update-alternatives..."
    sudo update-alternatives --config php
}

# Function to install LAMP and switch PHP on Gentoo
install_gentoo() {
    echo "Updating package lists..."
    sudo emerge --sync

    echo "Installing Apache..."
    sudo emerge --ask www-servers/apache

    echo "Installing MariaDB..."
    sudo emerge --ask dev-db/mariadb
    sudo rc-update add mariadb default
    sudo /etc/init.d/mariadb start

    echo "Installing PHP $PHP_VERSION with necessary extensions..."
    sudo emerge --ask dev-lang/php:$(echo $PHP_VERSION | tr -d '.')

    echo "Configuring PHP version with eselect..."
    sudo eselect php set apache2 $(eselect php list apache2 | grep "$PHP_VERSION" | awk '{print $1}')
    sudo eselect php set cli $(eselect php list cli | grep "$PHP_VERSION" | awk '{print $1}')

    echo "Restarting Apache..."
    sudo /etc/init.d/apache2 restart

    echo "Installing phpMyAdmin..."
    sudo emerge --ask dev-db/phpmyadmin

    echo "Securing MariaDB installation..."
    sudo mysql_secure_installation
}

# Execute installation based on detected distro
if [[ "$DISTRO" == "ubuntu" ]]; then
    install_ubuntu
elif [[ "$DISTRO" == "gentoo" ]]; then
    install_gentoo
else
    echo "Distribution $DISTRO is not supported."
    exit 1
fi

echo "LAMP server setup complete with PHP $PHP_VERSION. Access phpMyAdmin at http://localhost/phpmyadmin."

