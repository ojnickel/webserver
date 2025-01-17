#!/bin/env bash

# Default values
USE_IPV6=false
SERVER_ALIAS=""
SSL_KEY_DIR="$HOME/.local/certs/"
WEB_SERVER=""
DISTRO=""

# Auto-detect distribution
auto_detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) DISTRO="ubuntu" ;;
            gentoo) DISTRO="gentoo" ;;
            *) echo "Error: Unsupported distribution detected: $ID"; exit 1 ;;
        esac
    else
        echo "Error: Unable to detect distribution."
        exit 1
    fi
}

# Function to create Apache virtual host
create_apache_vhost() {
    # HTTP configuration (port 80)
    sudo tee "$VHOST_CONF_HTTP" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName $DOMAIN_NAME
EOF

    if [[ -n "$SERVER_ALIAS" ]]; then
        sudo tee -a "$VHOST_CONF_HTTP" > /dev/null <<EOF
    ServerAlias $SERVER_ALIAS
EOF
    fi

    sudo tee -a "$VHOST_CONF_HTTP" > /dev/null <<EOF
    ServerAdmin webmaster@$DOMAIN_NAME
    DocumentRoot $DOC_ROOT

    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    ErrorLog $ERROR_LOG
    CustomLog $ACCESS_LOG combined
</VirtualHost>
EOF

    # HTTPS configuration (port 443)
    sudo tee "$VHOST_CONF_HTTPS" > /dev/null <<EOF
<VirtualHost *:443>
    ServerName $DOMAIN_NAME
EOF

    if [[ -n "$SERVER_ALIAS" ]]; then
        sudo tee -a "$VHOST_CONF_HTTPS" > /dev/null <<EOF
    ServerAlias $SERVER_ALIAS
EOF
    fi

    sudo tee -a "$VHOST_CONF_HTTPS" > /dev/null <<EOF
    ServerAdmin webmaster@$DOMAIN_NAME
    DocumentRoot $DOC_ROOT

    <Directory $DOC_ROOT>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>

    SSLEngine on
    SSLCertificateFile $SSL_CERT
    SSLCertificateKeyFile $SSL_KEY

    ErrorLog $ERROR_LOG
    CustomLog $ACCESS_LOG combined
</VirtualHost>
EOF

    # Add entries to /etc/hosts
    edit_hosts

    # Enable site and restart Apache
    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo a2ensite "${DOMAIN_NAME}_http.conf"
        sudo a2ensite "${DOMAIN_NAME}_https.conf"
        sudo systemctl restart apache2
    elif [[ "$DISTRO" == "gentoo" ]]; then
        sudo rc-service apache2 restart
    fi

    echo "Apache virtual host created and enabled."
}

# Function to create Nginx virtual host
create_nginx_vhost() {
    # HTTP configuration (port 80)
    sudo tee "$VHOST_CONF_HTTP" > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN_NAME $SERVER_ALIAS;

    root $DOC_ROOT;
    index index.html index.htm;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log $ACCESS_LOG;
    error_log $ERROR_LOG;
}
EOF

    # HTTPS configuration (port 443)
    sudo tee "$VHOST_CONF_HTTPS" > /dev/null <<EOF
server {
    listen 443 ssl;
    server_name $DOMAIN_NAME $SERVER_ALIAS;

    root $DOC_ROOT;
    index index.html index.htm;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;

    location / {
        try_files \$uri \$uri/ =404;
    }

    access_log $ACCESS_LOG;
    error_log $ERROR_LOG;
}
EOF

    # Add entries to /etc/hosts
    edit_hosts

    # Enable site and reload Nginx
    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo ln -sf "$VHOST_CONF_HTTP" /etc/nginx/sites-enabled/
        sudo ln -sf "$VHOST_CONF_HTTPS" /etc/nginx/sites-enabled/
        sudo nginx -t && sudo systemctl reload nginx
    elif [[ "$DISTRO" == "gentoo" ]]; then
        sudo ln -sf "$VHOST_CONF_HTTP" /etc/nginx/conf.d/
        sudo ln -sf "$VHOST_CONF_HTTPS" /etc/nginx/conf.d/
        sudo rc-service nginx reload
    fi

    echo "Nginx virtual host created and enabled."
}

# Check if WSL2 environment
is_wsl2() {
    grep -qEi "(Microsoft|WSL2)" /proc/version &> /dev/null
    return $?
}

# Edit /etc/hosts or Windows hosts file based on environment
edit_hosts() {
    if is_wsl2; then
        if powershell.exe -Command "Get-Content C:\Windows\System32\drivers\etc\hosts" | grep -q "$DOMAIN_NAME"; then
            echo "$DOMAIN_NAME already exists in Windows hosts file."
        else
            powershell.exe -Command "Add-Content C:\Windows\System32\drivers\etc\hosts '127.0.0.1 $DOMAIN_NAME'"
            echo "Added $DOMAIN_NAME to Windows hosts file."
        fi
    else
        if grep -q "$DOMAIN_NAME" /etc/hosts; then
            echo "$DOMAIN_NAME already exists in /etc/hosts."
        else
            echo "127.0.0.1 $DOMAIN_NAME" | sudo tee -a /etc/hosts > /dev/null
            echo "Added $DOMAIN_NAME to /etc/hosts."
        fi
    fi
}

# Function to display help
usage() {
    echo "Usage: sudo $0 -t <document_root> -n <domain_name> -s <apache|nginx> [-k <ssl_key_dir>] [-a <server_alias>] [-6]"
    echo "  -t  Root document directory (required)"
    echo "  -n  Domain name (required)"
    echo "  -s  Web server (apache or nginx, required)"
    echo "  -k  SSL directory (optional, default is ~/.local/certs)"
    echo "  -a  Server alias (optional, e.g., www.example.com)"
    echo "  -6  Enable IPv6 (optional)"
    exit 1
}

# Parse arguments
while getopts "t:n:s:k:a:6" opt; do
    case "$opt" in
        t) DOC_ROOT=$OPTARG ;;
        n) DOMAIN_NAME=$OPTARG ;;
        s) WEB_SERVER=$OPTARG ;;
        k) SSL_KEY_DIR=$OPTARG ;;
        a) SERVER_ALIAS=$OPTARG ;;
        6) USE_IPV6=true ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
if [[ -z "$DOC_ROOT" || -z "$DOMAIN_NAME" || -z "$WEB_SERVER" ]]; then
    usage
fi

# Auto-detect distribution if not explicitly set
auto_detect_distro

# Locate SSL certificate and key
if [[ -d "$SSL_KEY_DIR$DOMAIN_NAME" ]]; then
    for file in "$SSL_KEY_DIR$DOMAIN_NAME"/*; do
        if [[ "$file" == *.key ]]; then
            SSL_KEY=$file
        elif [[ "$file" == *.crt ]]; then
            SSL_CERT=$file
        fi
    done
fi

if [[ -z "$SSL_CERT" || -z "$SSL_KEY" ]]; then
    echo "Error: SSL certificate or key not found in $SSL_KEY_DIR$DOMAIN_NAME."
    exit 1
fi

# Define log file paths
ERROR_LOG="/var/log/${WEB_SERVER}/${DOMAIN_NAME}_error.log"
ACCESS_LOG="/var/log/${WEB_SERVER}/${DOMAIN_NAME}_access.log"

# Set paths for configuration files
if [[ "$WEB_SERVER" == "apache" ]]; then
    if [[ "$DISTRO" == "ubuntu" ]]; then
        VHOST_CONF_HTTP="/etc/apache2/sites-available/${DOMAIN_NAME}_http.conf"
        VHOST_CONF_HTTPS="/etc/apache2/sites-available/${DOMAIN_NAME}_https.conf"
    elif [[ "$DISTRO" == "gentoo" ]]; then
        VHOST_CONF_HTTP="/etc/apache2/vhosts.d/${DOMAIN_NAME}_http.conf"
        VHOST_CONF_HTTPS="/etc/apache2/vhosts.d/${DOMAIN_NAME}_https.conf"
    fi
elif [[ "$WEB_SERVER" == "nginx" ]]; then
    if [[ "$DISTRO" == "ubuntu" ]]; then
        VHOST_CONF_HTTP="/etc/nginx/sites-available/${DOMAIN_NAME}_http"
        VHOST_CONF_HTTPS="/etc/nginx/sites-available/${DOMAIN_NAME}_https"
    elif [[ "$DISTRO" == "gentoo" ]]; then
        VHOST_CONF_HTTP="/etc/nginx/conf.d/${DOMAIN_NAME}_http"
        VHOST_CONF_HTTPS="/etc/nginx/conf.d/${DOMAIN_NAME}_https"
    fi
fi

# Create virtual host based on the web server
if [[ "$WEB_SERVER" == "apache" ]]; then
    create_apache_vhost
elif [[ "$WEB_SERVER" == "nginx" ]]; then
    create_nginx_vhost
fi
