# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains shell scripts for automated server setup and configuration. The primary purpose is to streamline the deployment of web servers with common configurations across different Linux distributions.

## Core Scripts and Usage

### Server Stack Installation
- `./create-lamp.sh` - Sets up Linux, Apache, MySQL/MariaDB, PHP stack
- `./create-lemp.sh` - Sets up Linux, Nginx, MySQL/MariaDB, PHP stack

Both scripts:
- Auto-detect Ubuntu or Gentoo distributions
- Require root privileges (run with sudo)
- Prompt for PHP version selection
- Configure package repositories and install dependencies
- Set up database security

### Virtual Host Management
- `./create-vhost.sh` - Creates Apache or Nginx virtual hosts with SSL support

Usage: `sudo ./create-vhost.sh -n <domain_name> [options]`

Key options:
- `-n` Domain name (required)
- `-s` Web server (nginx|apache, default: nginx)
- `-t` Document root (optional, defaults to /var/www/html/<domain_name>)
- `-l` Enable self-signed SSL
- `-a` Server alias
- `-k` SSL directory (default: ~/.local/certs/)

### SSL Certificate Generation
- `./create-ssl-cert.sh` - Generates self-signed certificates or configures Let's Encrypt

Usage: `./create-ssl-cert.sh -d <domain_name> [options]`

Key options:
- `-d` Domain name (required)
- `-t` Certificate type (1=self-signed, 2=Let's Encrypt, default: 2)
- `-w` Web server for Certbot (nginx|apache|none)
- `-k` Key size (default: 4096)
- `-v` Validity days (default: 365)

## Architecture

### Distribution Support
The scripts support two Linux distributions with different package managers and service management:
- **Ubuntu**: Uses apt, systemctl, sites-available/sites-enabled structure
- **Gentoo**: Uses emerge, rc-service, different configuration paths

### Web Server Configuration
- **Nginx**: Uses sites-available/sites-enabled (Ubuntu) or conf.d (Gentoo)
- **Apache**: Uses sites-available/sites-enabled (Ubuntu) or vhosts.d (Gentoo)

### SSL Integration
- Self-signed certificates stored in `~/.local/certs/<domain>/`
- Let's Encrypt integration via Certbot with automatic web server configuration
- Automatic HTTP to HTTPS redirects when SSL is enabled

### Host File Management
- Automatic /etc/hosts entries for local development
- WSL2 detection with Windows hosts file integration

## File Structure
- Main scripts in repository root
- Example configuration: `kpx.nickel.icu_http` (Nginx vhost with SSL and basic auth)
- Generated certificates: `~/.local/certs/`
- Web document roots: `/var/www/html/<domain_name>/`
- Log files: `/var/log/{nginx|apache2}/<domain>_{access|error}.log`

## Development Notes
- All scripts include distribution auto-detection
- Root privilege validation before execution
- Interactive prompts for missing required parameters
- Comprehensive error handling and validation
- Modular functions for reusability across different server types