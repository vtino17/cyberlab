#!/bin/bash
set -euo pipefail

CYBERLAB_VERSION="1.0.0"
CYBERLAB_DIR="${CYBERLAB_DIR:-$HOME/.cyberlab}"
export CYBERLAB_DIR

BOLD='\033[1m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()    { echo -e "${GREEN}[+]${NC} $1"; }
warn()   { echo -e "${YELLOW}[!]${NC} $1"; }
error()  { echo -e "${RED}[x]${NC} $1"; exit 1; }

detect_os() {
    case "$(uname -s)" in
        Linux)  OS="linux" ;;
        Darwin) OS="macos" ;;
        *)      error "Unsupported OS: $(uname -s)" ;;
    esac
    ARCH=$(uname -m)
    log "Detected $OS ($ARCH)"
}

check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        warn "Some features require root. Run with sudo if you want full deployment."
    fi
}

check_docker() {
    if command -v docker &>/dev/null; then
        log "Docker found: $(docker --version)"
    else
        error "Docker is required. Install it from https://docs.docker.com/engine/install/ and rerun CyberLab."
    fi
    if docker compose version &>/dev/null; then
        log "Docker Compose found"
    else
        error "Docker Compose v2 is required. Install the official plugin and rerun CyberLab."
    fi
}

download_file() {
    local url="$1" destination="$2" temporary
    command -v curl >/dev/null 2>&1 || error "curl is required to download CyberLab assets."
    temporary="$(mktemp "${destination}.tmp.XXXXXX")"
    if ! curl -fsSL "$url" -o "$temporary"; then
        rm -f -- "$temporary"
        error "Failed to download $url"
    fi
    mv -- "$temporary" "$destination"
}

deploy_monitoring() {
    log "Deploying monitoring stack (Wazuh, Prometheus, Grafana)..."
    mkdir -p "$CYBERLAB_DIR"
    cp "$(dirname "$0")/docker/compose.yml" "$CYBERLAB_DIR/docker-compose.yml" 2>/dev/null || \
    download_file "https://raw.githubusercontent.com/vtino17/cyberlab/main/docker/compose.yml" "$CYBERLAB_DIR/docker-compose.yml"

    cd "$CYBERLAB_DIR"
    docker compose pull 2>/dev/null || true
    docker compose up -d 2>/dev/null || docker-compose up -d
    log "Monitoring stack deployed"
}

deploy_mikrotik() {
    log "MikroTik configs ready at $CYBERLAB_DIR/configs/mikrotik/"
    mkdir -p "$CYBERLAB_DIR/configs/mikrotik"
    for f in vlan-config firewall-base dns-config; do
        download_file "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/mikrotik/$f.rsc" "$CYBERLAB_DIR/configs/mikrotik/$f.rsc"
    done
    log "Import via WinBox or SCP: scp $CYBERLAB_DIR/configs/mikrotik/*.rsc admin@MIKROTIK_IP:/"
}

deploy_pfsense() {
    log "pfSense configs ready at $CYBERLAB_DIR/configs/pfsense/"
    mkdir -p "$CYBERLAB_DIR/configs/pfsense"
    for f in firewall-rules nat-rules; do
        download_file "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/pfsense/$f.xml" "$CYBERLAB_DIR/configs/pfsense/$f.xml"
    done
    log "Import via pfSense WebGUI: Diagnostics > Backup & Restore"
}

deploy_endpoints() {
    log "Endpoint hardening scripts ready at $CYBERLAB_DIR/configs/endpoints/"
    mkdir -p "$CYBERLAB_DIR/configs/endpoints"
    download_file "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/endpoints/windows-hardening.ps1" "$CYBERLAB_DIR/configs/endpoints/windows-hardening.ps1"
    echo "Windows: powershell -ExecutionPolicy Bypass -File $CYBERLAB_DIR/configs/endpoints/windows-hardening.ps1"
}

deploy_wazuh() {
    log "Wazuh custom decoders ready at $CYBERLAB_DIR/configs/wazuh/"
    mkdir -p "$CYBERLAB_DIR/configs/wazuh"
    download_file "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/wazuh/decoders.xml" "$CYBERLAB_DIR/configs/wazuh/decoders.xml"
    log "Copy to Wazuh manager: docker cp $CYBERLAB_DIR/configs/wazuh/decoders.xml wazuh-manager:/var/ossec/etc/decoders/"
}

menu() {
    echo ""
    echo "============================================"
    echo " CyberLab v$CYBERLAB_VERSION"
    echo " One-Click Security Lab Deployer"
    echo "============================================"
    echo ""
    echo " Select components to deploy:"
    echo "  1) Monitoring stack (Wazuh + Prometheus + Grafana)"
    echo "  2) MikroTik configs"
    echo "  3) pfSense configs"
    echo "  4) Endpoint hardening scripts"
    echo "  5) Wazuh custom decoders"
    echo "  6) Deploy ALL"
    echo "  0) Exit"
    echo ""
    read -rp "Choose [0-6]: " choice
    echo ""

    case $choice in
        1) deploy_monitoring ;;
        2) deploy_mikrotik ;;
        3) deploy_pfsense ;;
        4) deploy_endpoints ;;
        5) deploy_wazuh ;;
        6) deploy_monitoring && deploy_mikrotik && deploy_pfsense && deploy_endpoints && deploy_wazuh && log "Full deployment complete" ;;
        0) exit 0 ;;
        *) warn "Invalid choice" && menu ;;
    esac
}

main() {
    echo ""
    echo "╔═══════════════════════════════════════════╗"
    echo "║           CyberLab v$CYBERLAB_VERSION             ║"
    echo "║    Security Lab One-Click Deployer        ║"
    echo "╚═══════════════════════════════════════════╝"
    echo ""

    detect_os
    check_root
    check_docker

    if [ $# -eq 0 ]; then
        menu
    else
        case "$1" in
            --all)        deploy_monitoring; deploy_mikrotik; deploy_pfsense; deploy_endpoints; deploy_wazuh; log "Done" ;;
            --monitoring) deploy_monitoring ;;
            --mikrotik)   deploy_mikrotik ;;
            --pfsense)    deploy_pfsense ;;
            --endpoints)  deploy_endpoints ;;
            --wazuh)      deploy_wazuh ;;
            *)            warn "Usage: $0 [--all|--monitoring|--mikrotik|--pfsense|--endpoints|--wazuh]" ;;
        esac
    fi

    echo ""
    log "Access your lab:"
    echo "  Wazuh Dashboard:  https://localhost"
    echo "  Grafana:          http://localhost:3000"
    echo "  Prometheus:       http://localhost:9090"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    main "$@"
fi
