#!/usr/bin/env bash

SSL_KEY_DIR="$HOME/.local/certs/"
WEB_SERVER="nginx"
DISTRO=""

auto_detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        case "$ID" in
            ubuntu) DISTRO="ubuntu" ;;
            gentoo) DISTRO="gentoo" ;;
            *) echo "Error: Unsupported distribution: $ID"; exit 1 ;;
        esac
    else
        echo "Error: Unable to detect distribution."
        exit 1
    fi
}

usage() {
    echo "Usage: sudo $0 -n <domain_name> [-s <nginx|apache>] [-k <ssl_key_dir>]"
    echo "  -n  Domain name (required)"
    echo "  -s  Web server (optional, default is nginx)"
    echo "  -k  SSL directory (optional, default is ~/.local/certs/)"
    exit 1
}

delete_vhost() {
    echo "Deleting virtual host: $DOMAIN_NAME"

    if [[ "$WEB_SERVER" == "apache" ]]; then
        if [[ "$DISTRO" == "ubuntu" ]]; then
            sudo a2dissite "${DOMAIN_NAME}_http.conf" 2>/dev/null
            sudo a2dissite "${DOMAIN_NAME}_https.conf" 2>/dev/null
            sudo rm -f "/etc/apache2/sites-available/${DOMAIN_NAME}_http.conf"
            sudo rm -f "/etc/apache2/sites-available/${DOMAIN_NAME}_https.conf"
            sudo systemctl restart apache2
        elif [[ "$DISTRO" == "gentoo" ]]; then
            sudo rm -f "/etc/apache2/vhosts.d/${DOMAIN_NAME}_http.conf"
            sudo rm -f "/etc/apache2/vhosts.d/${DOMAIN_NAME}_https.conf"
            sudo rc-service apache2 restart
        fi
    else
        if [[ "$DISTRO" == "ubuntu" ]]; then
            sudo rm -f "/etc/nginx/sites-enabled/${DOMAIN_NAME}_http"
            sudo rm -f "/etc/nginx/sites-enabled/${DOMAIN_NAME}_https"
            sudo rm -f "/etc/nginx/sites-available/${DOMAIN_NAME}_http"
            sudo rm -f "/etc/nginx/sites-available/${DOMAIN_NAME}_https"
            sudo nginx -t && sudo systemctl reload nginx
        elif [[ "$DISTRO" == "gentoo" ]]; then
            sudo rm -f "/etc/nginx/conf.d/${DOMAIN_NAME}_http"
            sudo rm -f "/etc/nginx/conf.d/${DOMAIN_NAME}_https"
            sudo rc-service nginx reload
        fi
    fi

    if [[ -d "$SSL_KEY_DIR$DOMAIN_NAME" ]]; then
        rm -rf "$SSL_KEY_DIR$DOMAIN_NAME"
        echo "Removed cert: $SSL_KEY_DIR$DOMAIN_NAME"
    fi

    if grep -q "$DOMAIN_NAME" /etc/hosts; then
        sudo sed -i "/$DOMAIN_NAME/d" /etc/hosts
        echo "Removed $DOMAIN_NAME from /etc/hosts."
    fi

    echo "Virtual host $DOMAIN_NAME deleted."
}

while getopts "n:s:k:" opt; do
    case "$opt" in
        n) DOMAIN_NAME=$OPTARG ;;
        s) WEB_SERVER=$OPTARG ;;
        k) SSL_KEY_DIR=$OPTARG ;;
        *) usage ;;
    esac
done

if [[ -z "$DOMAIN_NAME" ]]; then
    usage
fi

auto_detect_distro
delete_vhost
