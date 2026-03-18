#!/bin/bash
set -e # Exit immediately if a command fails

# ==============================================================================
# Docker Installation & Configuration Script for Ubuntu
# Installs Docker CE, Docker Compose, and configures optimal settings
# ==============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default configuration
DOCKER_LOGGING_DRIVER="json-file"
MAX_LOG_SIZE="100m"
MAX_LOG_FILES="3"
STORAGE_DRIVER="overlay2"

echo "=========================================="
echo " Docker Installation Tool"
echo "=========================================="
echo "This script will install Docker CE and Docker Compose"
echo "------------------------------------------"
echo "Options:"
echo "1) Install Docker CE + Docker Compose"
echo "2) Configure Docker daemon.json (tuning)"
echo "3) Uninstall Docker completely"
echo "4) Exit"
echo "=========================================="
read -p "Enter your choice (1-4): " choice

# ------------------------------------------------------------------------------
# Function: Check if running as root or with sudo
# ------------------------------------------------------------------------------
check_privileges() {
    if [[ $EUID -eq 0 ]] || sudo -v 2>/dev/null; then
        return 0
    else
        log_error "This script requires sudo privileges"
        exit 1
    fi
}

# ------------------------------------------------------------------------------
# Function: Install Docker CE
# ------------------------------------------------------------------------------
install_docker() {
    check_privileges
    log_info "Starting Docker CE installation..."

    # 1. Remove old versions (if any)
    log_info "Removing old Docker packages..."
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

    # 2. Install prerequisites
    log_info "Installing prerequisites..."
    sudo apt-get update
    sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        software-properties-common

    # 3. Add Docker's official GPG key
    log_info "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # 4. Add Docker repository
    log_info "Adding Docker repository..."
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # 5. Install Docker CE
    log_info "Installing Docker packages..."
    sudo apt-get update
    sudo apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # 6. Configure daemon.json
    log_info "Configuring Docker daemon..."
    ACTUAL_USER="${SUDO_USER:-$(whoami)}"

    # Create or update daemon.json
    sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "${DOCKER_LOGGING_DRIVER}",
  "log-opts": {
    "max-size": "${MAX_LOG_SIZE}",
    "max-file": "${MAX_LOG_FILES}"
  },
  "storage-driver": "${STORAGE_DRIVER}",
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "live-restore": true
}
EOF

    # 7. Start and enable Docker service
    log_info "Starting Docker service..."
    sudo systemctl daemon-reload
    sudo systemctl enable docker
    sudo systemctl restart docker
    sudo systemctl status docker --no-pager -n 3

    # 8. Add user to docker group (if not root)
    if [ "$ACTUAL_USER" != "root" ]; then
        log_info "Adding user '$ACTUAL_USER' to docker group..."
        sudo usermod -aG docker "$ACTUAL_USER"
        log_warn "User '$ACTUAL_USER' added to docker group. You may need to log out and back in for this to take effect."
    fi

    # 9. Verify installation
    log_info "Verifying Docker installation..."
    sudo docker --version
    sudo docker compose version

    # 10. Run hello-world test
    log_info "Running Docker hello-world test..."
    sudo docker run --rm hello-world || log_warn "Hello-world test completed with warnings (may be network-related)"

    echo ""
    echo "=========================================="
    echo " Docker Installation Complete!"
    echo "=========================================="
    echo ""
    echo "Docker version: $(sudo docker --version)"
    echo "Docker Compose version: $(sudo docker compose version 2>/dev/null || echo 'Not available')"
    echo ""
    if [ "$ACTUAL_USER" != "root" ]; then
        echo "To use Docker without sudo:"
        echo "  1. Log out and log back in"
        echo "  2. Or run: newgrp docker"
        echo ""
    fi
    echo "Test with: docker run hello-world"
    echo "=========================================="
}

# ------------------------------------------------------------------------------
# Function: Configure Docker daemon.json (advanced tuning)
# ------------------------------------------------------------------------------
configure_docker() {
    check_privileges
    log_info "Configuring Docker daemon settings..."

    if [ ! -f "/etc/docker/daemon.json" ]; then
        log_warn "No existing daemon.json found. Creating new one."
    else
        log_info "Backing up existing configuration to /etc/docker/daemon.json.backup"
        sudo cp /etc/docker/daemon.json /etc/docker/daemon.json.backup
    fi

    echo ""
    echo "Docker Daemon Configuration Options:"
    echo "------------------------------------------"
    echo "1) Production (Default - balanced)"
    echo "2) High Performance (optimized for throughput)"
    echo "3) Low Memory (optimized for small instances)"
    echo "4) Custom configuration"
    echo "5) Cancel"
    echo "------------------------------------------"
    read -p "Enter choice (1-5): " config_choice

    case $config_choice in
        1)
            # Production defaults
            sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "live-restore": true
}
EOF
            ;;
        2)
            # High performance tuning
            sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "200m",
    "max-file": "5"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "iptables": false,
  "ip-forward": true,
  "ip-masq": false,
  "live-restore": true,
  "default-runtime": "runc",
  "runtimes": {
    "runc": {
      "path": "runc"
    },
    "nvidia": {
      "path": "nvidia-container-runtime",
      "runtimeArgs": []
    }
  }
}
EOF
            ;;
        3)
            # Low memory tuning
            sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "50m",
    "max-file": "2"
  },
  "storage-driver": "overlay2",
  "iptables": true,
  "ip-forward": true,
  "ip-masq": true,
  "live-restore": false,
  "max-concurrent-downloads": 3,
  "max-concurrent-uploads": 5
}
EOF
            ;;
        4)
            # Custom configuration
            log_info "Enter your custom JSON configuration:"
            log_info "Example: {\"log-opts\": {\"max-size\": \"100m\"}}"
            read -p "JSON config: " custom_config
            echo "$custom_config" | sudo tee /etc/docker/daemon.json > /dev/null
            ;;
        5)
            log_info "Configuration cancelled."
            return
            ;;
        *)
            log_error "Invalid choice"
            return
            ;;
    esac

    # Restart Docker to apply changes
    log_info "Restarting Docker service..."
    sudo systemctl restart docker
    sleep 2
    sudo systemctl status docker --no-pager -n 3

    echo ""
    log_info "Current Docker configuration:"
    sudo cat /etc/docker/daemon.json | python3 -m json.tool 2>/dev/null || sudo cat /etc/docker/daemon.json
    echo ""
    log_info "Docker daemon configuration updated successfully!"
}

# ------------------------------------------------------------------------------
# Function: Uninstall Docker
# ------------------------------------------------------------------------------
uninstall_docker() {
    check_privileges
    log_warn "This will completely remove Docker, containers, images, volumes, and configuration!"
    read -p "Are you absolutely sure? (y/N): " confirm

    if [[ ! $confirm =~ ^[Yy]$ ]]; then
        log_info "Uninstall cancelled."
        return
    fi

    log_info "Stopping Docker service..."
    sudo systemctl stop docker || true
    sudo systemctl disable docker || true

    log_info "Removing Docker packages..."
    sudo apt-get purge -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo apt-get autoremove -y
    sudo apt-get autoclean

    log_info "Removing Docker data..."
    sudo rm -rf /var/lib/docker
    sudo rm -rf /var/lib/containerd
    sudo rm -rf /etc/docker
    sudo rm -rf /etc/containerd
    sudo rm -f /etc/apt/sources.list.d/docker.list
    sudo rm -f /usr/share/keyrings/docker-archive-keyring.gpg

    # Remove user from docker group
    ACTUAL_USER="${SUDO_USER:-$(whoami)}"
    if [ "$ACTUAL_USER" != "root" ] && groups "$ACTUAL_USER" | grep -q docker; then
        log_info "Removing user '$ACTUAL_USER' from docker group..."
        sudo gpasswd -d "$ACTUAL_USER" docker
    fi

    echo ""
    echo "=========================================="
    echo " Docker Uninstall Complete!"
    echo "=========================================="
    echo "All Docker data and configurations have been removed."
}

# ------------------------------------------------------------------------------
# Main Menu Logic
# ------------------------------------------------------------------------------
case $choice in
    1)
        install_docker
        ;;
    2)
        configure_docker
        ;;
    3)
        uninstall_docker
        ;;
    4)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac
