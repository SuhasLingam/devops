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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "=========================================="
echo " Kubernetes MASTER Node Setup"
echo "=========================================="

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

# 6. Initialize Kubernetes master
log_info "Initializing Kubernetes master node..."
sudo kubeadm init --cri-socket unix:///var/run/cri-dockerd.sock --ignore-preflight-errors=all

# 7. Setup kubectl for current user
log_info "Setting up kubectl..."
mkdir -p $HOME/.kube
sudo cp -f /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# 8. Generate join command for worker nodes
log_info "Generating join command for worker nodes..."
JOIN_CMD=$(sudo kubeadm token create --print-join-command)
JOIN_CMD="$JOIN_CMD --cri-socket unix:///var/run/cri-dockerd.sock"
echo "$JOIN_CMD" > kube_join_command.sh
chmod +x kube_join_command.sh

# 9. Start HTTP server for worker nodes to download join command
log_info "Starting HTTP server for worker nodes to fetch join command..."
MASTER_IP=$(hostname -I | awk '{print $1}')
cd $(dirname "$0")
python3 -m http.server 8888 --bind 0.0.0.0 &>/dev/null &
HTTP_PID=$!
log_info "HTTP server running on ${MASTER_IP}:8888 (PID: $HTTP_PID)"

# 10. Install Calico networking
log_info "Installing Calico networking..."
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.24.1/manifests/calico.yaml

echo ""
echo "=========================================="
echo " MASTER SETUP COMPLETE!"
echo "=========================================="
echo ""
echo "On worker nodes, the script will auto-download"
echo "the join command from this master."
echo ""
echo "Master IP: ${MASTER_IP}"
echo "Or manually run on workers:"
echo "  $JOIN_CMD"
echo ""
echo "Verify with: kubectl get nodes"
echo "=========================================="
echo ""
echo "Note: HTTP server (PID $HTTP_PID) is running to serve"
echo "the join command. It will be stopped in 30 minutes."
echo "To stop manually: kill $HTTP_PID"
echo ""

# Auto-stop HTTP server after 30 minutes
(sleep 1800 && kill $HTTP_PID 2>/dev/null && echo "[INFO] HTTP server stopped.") &
