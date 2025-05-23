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

# Function to install LEMP on Ubuntu
install_ubuntu() {
    echo "Updating package lists..."
    sudo apt-get update

    echo "Adding Ondrej PHP repository..."
    sudo add-apt-repository ppa:ondrej/php -y
    sudo apt-get update

    echo "Installing Nginx..."
    sudo apt-get install -y nginx

    echo "Installing MariaDB..."
    sudo apt-get install -y mariadb-server

    echo "Installing PHP and necessary extensions..."
    sudo apt-get install -y php php-fpm php-{bz2,curl,intl,mysql,readline,xml,common,cli}

    echo "Configuring Nginx to use PHP..."
    sudo tee /etc/nginx/sites-available/default <<EOF
server {
    listen 80;
    server_name localhost;

    root /var/www/html;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

    echo "Restarting Nginx and PHP services..."
    sudo systemctl restart nginx
    sudo systemctl restart php-fpm

    echo "Securing MariaDB installation..."
    sudo mysql_secure_installation
}

# Function to install LEMP on Gentoo
install_gentoo() {
    echo "Updating package lists..."
    sudo emerge --sync

    echo "Installing Nginx..."
    sudo emerge --ask www-servers/nginx

    echo "Installing MariaDB..."
    sudo emerge --ask dev-db/mariadb
    sudo rc-update add mariadb default
    sudo /etc/init.d/mariadb start

    echo "Installing PHP and necessary extensions..."
    sudo emerge --ask dev-lang/php

    echo "Configuring Nginx to use PHP..."
    sudo tee /etc/nginx/nginx.conf <<EOF
http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen       80;
        server_name  localhost;
        root         /var/www/localhost/htdocs;

        location / {
            index  index.php index.html index.htm;
        }

        location ~ \.php$ {
            fastcgi_pass   unix:/var/run/php-fpm/php-fpm.sock;
            fastcgi_index  index.php;
            include        fastcgi.conf;
        }
    }
}
EOF

    echo "Restarting Nginx and PHP services..."
    sudo /etc/init.d/nginx restart
    sudo /etc/init.d/php-fpm restart

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

echo "LEMP server setup complete. Access your site at http://localhost."
