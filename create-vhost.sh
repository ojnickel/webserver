#!/bin/env bash

# Default values
USE_IPV6=false
SERVER_ALIAS=""
EMAIL="webmaster@nickel.icu"
SELF_SIGNED=0 #default. only when turned on -> self-signed certificates
SSL_KEY_DIR="$HOME/.local/certs/"
WEB_SERVER="nginx" #default
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

#Function to add https for apache/nginx
ssl(){
    # Check if certs exist
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

    if [[ "$WEB_SERVER" == "apache" ]]; then
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
    ServerAdmin $EMAIL
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

    elif [[ "$WEB_SERVER" == "nginx" ]]; then
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
    else
        echo "Error! Web server not specified"
        exit 1
    fi
}

# Function to create Apache virtual host
create_apache_vhost() {
    sudo mkdir -p "/var/log/apache2"
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
    ServerAdmin $EMAIL
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

    if [[ $SELF_SIGNED -eq 1 ]]; then
        ssl
    fi

    edit_hosts

    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo a2ensite "${DOMAIN_NAME}_http.conf"
        [[ $SELF_SIGNED -eq 1 ]] && sudo a2ensite "${DOMAIN_NAME}_https.conf"
        sudo systemctl restart apache2
    elif [[ "$DISTRO" == "gentoo" ]]; then
        sudo rc-service apache2 restart
    fi

    echo "Apache virtual host created and enabled."
}

# Function to create Nginx virtual host
create_nginx_vhost() {
    sudo mkdir -p "/var/log/nginx"
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

    if [[ $SELF_SIGNED -eq 1 ]]; then
        ssl
    fi

    edit_hosts

    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo ln -sf "$VHOST_CONF_HTTP" /etc/nginx/sites-enabled/
        if [[ $SELF_SIGNED -eq 1 ]]; then
            sudo ln -sf "$VHOST_CONF_HTTPS" /etc/nginx/sites-enabled/
        fi
        sudo nginx -t && sudo systemctl reload nginx
    elif [[ "$DISTRO" == "gentoo" ]]; then
        sudo ln -sf "$VHOST_CONF_HTTP" /etc/nginx/conf.d/
        if [[ $SELF_SIGNED -eq 1 ]]; then
            sudo ln -sf "$VHOST_CONF_HTTPS" /etc/nginx/conf.d/
        fi
        sudo rc-service nginx reload
    fi

    echo "Nginx virtual host created and enabled."
}

# Check if WSL2 environment
is_wsl2() {
    grep -qEi "(Microsoft|WSL2)" /proc/version &> /dev/null
    return $?
}

# Edit /etc/hosts or Windows hosts file
edit_hosts() {
    if is_wsl2; then
        if powershell.exe -Command "Get-Content C:\\Windows\\System32\\drivers\\etc\\hosts" | grep -q "$DOMAIN_NAME"; then
            echo "$DOMAIN_NAME already exists in Windows hosts file."
        else
            powershell.exe -Command "Add-Content C:\\Windows\\System32\\drivers\\etc\\hosts '127.0.0.1 $DOMAIN_NAME'"
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
    echo "Usage: sudo $0 -t <document_root> -n <domain_name> [-s <nginx|apache>] [-k <ssl_key_dir>] [-a <server_alias>] [-6] [-l]"
    echo "  -t  Root document directory (optional, default is /var/www/ + Domain name)" 
    echo "  -n  Domain name (required)"
    echo "  -s  Web server (optional, default is nginx)"
    echo "  -k  SSL directory (optional, default is ~/.local/certs/)"
    echo "  -a  Server alias (optional)"
    echo "  -6  Enable IPv6"
    echo "  -l  Enable self-signed SSL"
    exit 1
}

# Parse arguments
while getopts "t:n:s:k:a:6l" opt; do
    case "$opt" in
        t) DOC_ROOT=$OPTARG ;;
        n) DOMAIN_NAME=$OPTARG ;;
        s) WEB_SERVER=$OPTARG ;;
        k) SSL_KEY_DIR=$OPTARG ;;
        a) SERVER_ALIAS=$OPTARG ;;
        6) USE_IPV6=true ;;
        l) SELF_SIGNED=1 ;;
        *) usage ;;
    esac
done

#if [[ -z "$DOC_ROOT" || -z "$DOMAIN_NAME" ]]; then

if [[ -z "$DOMAIN_NAME" ]]; then
    usage
fi

#set default for Web directory
DOC_ROOT="/var/www/html/$DOMAIN_NAME"

auto_detect_distro

# check if Web directory exists, if not ask to create one 
if [[ ! -d "$DOC_ROOT" ]];then
    echo "$DOC_ROOT not found"
    echo "Create one? [y/n]"
    read a
    if [[ "$a" == "y" ]]; then
        mkdir -p "$DOC_ROOT"
        echo "$DOC_ROOT created"
    else
        exit 1
    fi
fi

ERROR_LOG="/var/log/${WEB_SERVER}/${DOMAIN_NAME}_error.log"
ACCESS_LOG="/var/log/${WEB_SERVER}/${DOMAIN_NAME}_access.log"

if [[ "$WEB_SERVER" == "apache" ]]; then
    if [[ "$DISTRO" == "ubuntu" ]]; then
        VHOST_CONF_HTTP="/etc/apache2/sites-available/${DOMAIN_NAME}_http.conf"
        VHOST_CONF_HTTPS="/etc/apache2/sites-available/${DOMAIN_NAME}_https.conf"
    else
        VHOST_CONF_HTTP="/etc/apache2/vhosts.d/${DOMAIN_NAME}_http.conf"
        VHOST_CONF_HTTPS="/etc/apache2/vhosts.d/${DOMAIN_NAME}_https.conf"
    fi
else
    if [[ "$DISTRO" == "ubuntu" ]]; then
        VHOST_CONF_HTTP="/etc/nginx/sites-available/${DOMAIN_NAME}_http"
        VHOST_CONF_HTTPS="/etc/nginx/sites-available/${DOMAIN_NAME}_https"
    else
        VHOST_CONF_HTTP="/etc/nginx/conf.d/${DOMAIN_NAME}_http"
        VHOST_CONF_HTTPS="/etc/nginx/conf.d/${DOMAIN_NAME}_https"
    fi
fi

if [[ "$WEB_SERVER" == "apache" ]]; then
    create_apache_vhost
else
    create_nginx_vhost
fi
