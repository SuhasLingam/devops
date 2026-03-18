#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo " Kubernetes WORKER NODE Setup"
echo "=========================================="

# Get master IP
read -p "Enter MASTER node IP address: " MASTER_IP

# 1. Configure sysctl for Kubernetes
log_info "Configuring sysctl parameters..."
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF
sudo sysctl --system

# 2. Disable swap
log_info "Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 3. Install Docker
log_info "Installing Docker..."
sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installDocker.sh -P /tmp
sudo chmod 755 /tmp/installDocker.sh
sudo bash /tmp/installDocker.sh
sudo systemctl restart docker.service

# 4. Install CRI-Dockerd
log_info "Installing CRI-Dockerd..."
sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installCRIDockerd.sh -P /tmp
sudo chmod 755 /tmp/installCRIDockerd.sh
sudo bash /tmp/installCRIDockerd.sh
sudo systemctl restart cri-docker.service

# 5. Install Kubernetes (kubeadm, kubelet, kubectl)
log_info "Installing Kubernetes components..."
sudo wget https://raw.githubusercontent.com/lerndevops/labs/master/scripts/installK8S.sh -P /tmp
sudo chmod 755 /tmp/installK8S.sh
sudo bash /tmp/installK8S.sh

# 6. Download join command from master and join the cluster
log_info "Downloading join command from master (${MASTER_IP})..."
if wget -q "http://${MASTER_IP}:8888/kube_join_command.sh" -O kube_join_command.sh 2>/dev/null; then
    log_info "Join command downloaded. Joining the cluster..."
    sudo bash ./kube_join_command.sh
else
    log_warn "Could not download from master HTTP server."
    log_warn "Make sure the master setup has completed and HTTP server is running."
    echo ""
    echo "Alternative: manually paste the join command from master."
    echo "It should look like:"
    echo "  kubeadm join <ip>:6443 --cri-socket unix:///var/run/cri-dockerd.sock --token <token> --discovery-token-ca-cert-hash sha256:<hash>"
    echo ""
    read -p "Paste join command here (or press Enter to exit): " JOIN_CMD
    if [ -z "$JOIN_CMD" ]; then
        log_error "No command entered. Exiting."
        exit 1
    fi
    log_info "Joining the cluster..."
    sudo $JOIN_CMD
fi

echo ""
echo "=========================================="
echo " NODE JOINED SUCCESSFULLY!"
echo "=========================================="
echo "Verify on master with: kubectl get nodes"
echo "=========================================="
