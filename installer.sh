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
        warn "Docker not found. Installing..."
        curl -fsSL https://get.docker.com | bash
        log "Docker installed"
    fi
    if command -v docker compose &>/dev/null; then
        log "Docker Compose found"
    else
        warn "Docker Compose not found. Installing plugin..."
        DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
        mkdir -p "$DOCKER_CONFIG/cli-plugins"
        curl -SL "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o "$DOCKER_CONFIG/cli-plugins/docker-compose"
        chmod +x "$DOCKER_CONFIG/cli-plugins/docker-compose"
        log "Docker Compose installed"
    fi
}

deploy_monitoring() {
    log "Deploying monitoring stack (Wazuh, Prometheus, Grafana)..."
    mkdir -p "$CYBERLAB_DIR"
    cp -r "$(dirname "$0")/docker/compose.yml" "$CYBERLAB_DIR/docker-compose.yml" 2>/dev/null || \
    curl -sL "https://raw.githubusercontent.com/vtino17/cyberlab/main/docker/compose.yml" -o "$CYBERLAB_DIR/docker-compose.yml"

    cd "$CYBERLAB_DIR"
    docker compose pull 2>/dev/null || true
    docker compose up -d 2>/dev/null || docker-compose up -d
    log "Monitoring stack deployed"
}

deploy_mikrotik() {
    log "MikroTik configs ready at $CYBERLAB_DIR/configs/mikrotik/"
    mkdir -p "$CYBERLAB_DIR/configs/mikrotik"
    for f in vlan-config firewall-base dns-config; do
        curl -sL "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/mikrotik/$f.rsc" -o "$CYBERLAB_DIR/configs/mikrotik/$f.rsc" 2>/dev/null || true
    done
    log "Import via WinBox or SCP: scp $CYBERLAB_DIR/configs/mikrotik/*.rsc admin@MIKROTIK_IP:/"
}

deploy_pfsense() {
    log "pfSense configs ready at $CYBERLAB_DIR/configs/pfsense/"
    mkdir -p "$CYBERLAB_DIR/configs/pfsense"
    for f in firewall-rules nat-rules; do
        curl -sL "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/pfsense/$f.xml" -o "$CYBERLAB_DIR/configs/pfsense/$f.xml" 2>/dev/null || true
    done
    log "Import via pfSense WebGUI: Diagnostics > Backup & Restore"
}

deploy_endpoints() {
    log "Endpoint hardening scripts ready at $CYBERLAB_DIR/configs/endpoints/"
    mkdir -p "$CYBERLAB_DIR/configs/endpoints"
    curl -sL "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/endpoints/windows-hardening.ps1" -o "$CYBERLAB_DIR/configs/endpoints/windows-hardening.ps1" 2>/dev/null || true
    echo "Windows: powershell -ExecutionPolicy Bypass -File $CYBERLAB_DIR/configs/endpoints/windows-hardening.ps1"
}

deploy_wazuh() {
    log "Wazuh custom decoders ready at $CYBERLAB_DIR/configs/wazuh/"
    mkdir -p "$CYBERLAB_DIR/configs/wazuh"
    curl -sL "https://raw.githubusercontent.com/vtino17/cyberlab/main/configs/wazuh/decoders.xml" -o "$CYBERLAB_DIR/configs/wazuh/decoders.xml" 2>/dev/null || true
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

main "$@"
