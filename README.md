# Webserver Setup Scripts

Automated shell scripts for setting up web servers with common configurations on Ubuntu and Gentoo Linux distributions.

## Features

- **Server Stack Installation**
  - LAMP (Linux, Apache, MySQL/MariaDB, PHP)
  - LEMP (Linux, Nginx, MySQL/MariaDB, PHP)
- **Virtual Host Management**
  - Apache and Nginx virtual host creation
  - Automatic configuration for different distributions
- **SSL Certificate Management**
  - Self-signed certificates (local development)
  - Let's Encrypt integration with Certbot
  - Automatic HTTPS configuration
- **Unified Command Interface**
  - `weser` dispatcher for all scripts
  - Simplified command syntax
  - Consistent help system

## Installation

Install the `weser` command dispatcher to your PATH:

```bash
./install.sh
```

This will install `weser` to `~/bin` and provide instructions for adding it to your PATH.

## Quick Start

### Using weser (Recommended)

```bash
# Install LAMP stack
weser lamp

# Install LEMP stack
weser lemp

# Create virtual host
weser vhost -n example.com

# Create virtual host with SSL
weser vhost -n example.com -l

# Generate SSL certificate
weser ssl -d example.com

# Get help
weser --help
weser vhost --help
```

### Direct Script Usage

```bash
# Install LAMP Stack
sudo ./create-lamp.sh

# Install LEMP Stack
sudo ./create-lemp.sh

# Create Virtual Host
sudo ./create-vhost.sh -n example.com -l

# Generate SSL Certificate
./create-ssl-cert.sh -d example.com -t 1
```

## Supported Distributions

- **Ubuntu**: Uses apt package manager and systemctl service management
- **Gentoo**: Uses emerge package manager and rc-service management

## Requirements

- Root privileges (scripts must be run with sudo)
- Internet connection for package installation
- For Let's Encrypt: Domain must resolve to server's IP address
