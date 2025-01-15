#!/bin/env bash

# Default values
USE_IPV6=false
SERVER_ALIAS=""
SSL_KEY_DIR="$HOME/.local/certs/"

# Detect distribution if not specified
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    DISTRO=${DISTRO:-$ID}
else
    echo "Warning: Distribution not supported by this script."
    exit 1
fi

# vHost configuration for port 80 and 443
create_vhost() {
    # port 80
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


    # Add IPv6 block for HTTP if enabled
    if [[ "$USE_IPV6" == true ]]; then
        sudo tee -a "$VHOST_CONF_HTTP" > /dev/null <<EOF

    <VirtualHost [::]:80>
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
    fi

    # Create HTTPS virtual host configuration (port 443)
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



# Add IPv6 block for HTTPS if enabled

if [[ "$USE_IPV6" == true ]]; then


    sudo tee -a "$VHOST_CONF_HTTPS" > /dev/null <<EOF
    <VirtualHost [::]:443>
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
    fi
}
# Function to display help
usage() {
    echo "Usage: sudo $0 -t <document_root> -n <domain_name> -k <ssl_key_dir> [-d <ubuntu|gentoo [-a <server_alias>] [-6]"
    echo "  -t  Root document directory (required)"
    echo "  -n  Domain name (required)"
    echo "  -k  SSL directory (optional, default is ~/.local/certs)"
    echo "  -d  Distribution (ubuntu or gentoo, auto-detects if omitted)"
    echo "  -a  Server alias (optional, e.g., www.example.com)"
    echo "  -6  Enable IPv6 (optional)"
    exit 1
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

# Parse arguments
while getopts "t:n:k:d:a:6" opt; do
    case "$opt" in
        t) DOC_ROOT=$OPTARG ;;
        n) DOMAIN_NAME=$OPTARG ;;
        k) SSL_KEY_DIR=$OPTARG ;;
        d) DISTRO=$OPTARG ;;
        a) SERVER_ALIAS=$OPTARG ;;
        6) USE_IPV6=true ;;
        *) usage ;;
    esac
done

# Ensure required parameters are provided
if [[ -z "$DOC_ROOT" || -z "$DOMAIN_NAME" ]]; then
    usage
fi

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
ERROR_LOG="/var/log/apache2/${DOMAIN_NAME}_error.log"
ACCESS_LOG="/var/log/apache2/${DOMAIN_NAME}_access.log"

# Set paths for configuration files
if [[ "$DISTRO" == "ubuntu" ]]; then
    VHOST_CONF_HTTP="/etc/apache2/sites-available/${DOMAIN_NAME}_http.conf"
    VHOST_CONF_HTTPS="/etc/apache2/sites-available/${DOMAIN_NAME}_https.conf"
else
    VHOST_CONF_HTTP="/etc/apache2/vhosts.d/${DOMAIN_NAME}_http.conf"
    VHOST_CONF_HTTPS="/etc/apache2/vhosts.d/${DOMAIN_NAME}_https.conf"
fi

# Create HTTP virtual host configuration (port 80 and 443)
create_vhost

# Add entry to hosts file
edit_hosts

# Enable site and restart Apache
if [[ "$DISTRO" == "ubuntu" ]]; then
    sudo a2ensite "${DOMAIN_NAME}_http.conf"
    sudo a2ensite "${DOMAIN_NAME}_https.conf"
    sudo systemctl restart apache2
else
    sudo rc-service apache2 restart
fi

echo "Separate HTTP and HTTPS virtual host configurations created and Apache restarted for $DISTRO."
