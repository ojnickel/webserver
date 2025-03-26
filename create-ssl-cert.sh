#!/bin/bash

# Default values
CERT_NAME=$(date +%s | sha256sum | base64 | head -c 8)
KEY_SIZE=4096
DAYS_VALID=365
BASE_DIR="$HOME/.local/certs"
DIRNAME=""
CERT_TYPE=1 # Default certificate type (1 = self-signed, 2 = Let's Encrypt)
WEB_SERVER="nginx" # Default web server for Certbot is nginx

# Function to display help
function usage() {
    echo "Usage: $0 -d <domain_name> [-k <key_size>] [-v <days_valid>] [-o <output_dir>] [-n <name>] [-t <cert_type>] [-w <web_server>]"
    echo "Options:"
    echo "  -c  Certificate name (optional, default is a random name)"
    echo "  -d  Domain name (required, e.g., example.com)"
    echo "  -k  Key size (optional, default is 4096)"
    echo "  -v  Validity in days (optional, default is 365)"
    echo "  -o  Output directory (optional, default is ~/local/certs/)"
    echo "  -n  Custom directory name for the key and cert (optional)"
    echo "  -t  Certificate type (1 = self-signed, 2 = Let's Encrypt, default is 1)"
    echo "  -w  Web server to configure for Certbot (optional, options: nginx, apache, none)"
    exit 1
}

# Function to generate a self-signed certificate
function generate_self_signed() {
    echo "Generating a self-signed certificate..."

    # Create output directory if it doesn't exist
    mkdir -p "$BASE_DIR/$DIRNAME"

    # Generate a private key
    echo "Generating a private key..."
    openssl genpkey -algorithm RSA -out "$KEY_FILE" -pkeyopt rsa_keygen_bits:$KEY_SIZE

    # Generate certificate signing request (CSR)
    echo "Generating a certificate signing request (CSR)..."
    openssl req -new -key "$KEY_FILE" -out "$BASE_DIR/$DIRNAME/$CERT_NAME.csr" -subj "/CN=$DOMAIN_NAME"

    # Generate self-signed certificate
    echo "Generating a self-signed certificate..."
    openssl x509 -req -days "$DAYS_VALID" -in "$BASE_DIR/$DIRNAME/$CERT_NAME.csr" -signkey "$KEY_FILE" -out "$CERT_FILE"

    # Cleanup CSR file (optional)
    rm "$BASE_DIR/$DIRNAME/$CERT_NAME.csr"

    echo "Self-signed certificate and key generated:"
    echo "  Key:  $KEY_FILE"
    echo "  Cert: $CERT_FILE"
}

# Function to configure Let's Encrypt certificate
function use_lets_encrypt() {
    echo "Using Let's Encrypt certificate with Certbot..."

    # Ensure `certbot` is installed
    if ! command -v sudo certbot &> /dev/null; then
        echo "Error: certbot is not installed. Install it with your package manager and try again."
        exit 1
    fi

    # Check which web server to use for Certbot
    case "$WEB_SERVER" in
        nginx)
            echo "Using NGINX plugin for Certbot..."
            sudo certbot --nginx -d "$DOMAIN_NAME" --agree-tos --register-unsafely-without-email
            ;;
        apache)
            echo "Using Apache plugin for Certbot..."
            sudo certbot --apache -d "$DOMAIN_NAME" --agree-tos --register-unsafely-without-email
            ;;
        none)
            echo "Using standalone mode for Certbot..."
            sudo certbot certonly --standalone --preferred-challenges http -d "$DOMAIN_NAME" --agree-tos --register-unsafely-without-email
            ;;
        *)
            echo "Error: Unsupported web server '$WEB_SERVER'. Use 'nginx', 'apache', or 'none'."
            exit 1
            ;;
    esac

    # Verify Let's Encrypt certificate exists
    LETSENCRYPT_DIR="/etc/letsencrypt/live/$DOMAIN_NAME"
    if [[ -d "$LETSENCRYPT_DIR" ]]; then
        # Update variables to point to Let's Encrypt certificates
        KEY_FILE="$LETSENCRYPT_DIR/privkey.pem"
        CERT_FILE="$LETSENCRYPT_DIR/fullchain.pem"

        echo "Let's Encrypt certificates found and will be used:"
        echo "  Key:  $KEY_FILE"
        echo "  Cert: $CERT_FILE"
    else
        echo "Error: Let's Encrypt certificates not found for domain $DOMAIN_NAME."
        exit 1
    fi
}

# Function to select and use the correct certificate type
function generate_or_use_certificate() {
    if [[ "$CERT_TYPE" -eq 1 ]]; then
        # Set file paths for self-signed certificates
        KEY_FILE="$BASE_DIR/$DIRNAME/$CERT_NAME.key"
        CERT_FILE="$BASE_DIR/$DIRNAME/$CERT_NAME.crt"

        # Generate a self-signed certificate
        generate_self_signed
    elif [[ "$CERT_TYPE" -eq 2 ]]; then
        # Use Let's Encrypt certificate (update KEY_FILE and CERT_FILE in the process)
        use_lets_encrypt
    else
        echo "Error: Invalid certificate type specified. Use 1 for self-signed or 2 for Let's Encrypt."
        usage
    fi
}

# Parse arguments
while getopts "c:d:k:v:o:n:t:w:" opt; do
    case "$opt" in
        c) CERT_NAME=$OPTARG ;;
        d) DOMAIN_NAME=$OPTARG ;;
        k) KEY_SIZE=$OPTARG ;;
        v) DAYS_VALID=$OPTARG ;;
        o) BASE_DIR=$OPTARG ;;
        n)
            if [[ -z $OPTARG ]]; then
                read -p "Enter a name for the output files: " DIRNAME
            else
                DIRNAME=$OPTARG
            fi
            ;;
        t) CERT_TYPE=$OPTARG ;;
        w) WEB_SERVER=$OPTARG ;;
        *) usage ;;
    esac
done

# Ensure domain name is provided
if [[ -z "$DOMAIN_NAME" ]]; then
    usage
fi

# Assign DOMAIN_NAME if DIRNAME is not set
if [[ -z "$DIRNAME" ]]; then
    DIRNAME="$DOMAIN_NAME"
fi

# Generate or use the correct certificate
generate_or_use_certificate
