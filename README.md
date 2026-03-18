# Devops Automation Scripts

This repository contains robust bash scripts to automate the deployment and management of standard Devops tools (Jenkins, Tomcat, SonarQube, PostgreSQL, Ansible, and Docker) on a fresh Linux server (e.g., Ubuntu on AWS EC2).

## Prerequisites
- A Linux server (Ubuntu 22.04+ recommended)
- **Minimum Specifications**:
  - For SonarQube: at least **2GB RAM** (e.g., `t3.small`), 8GB+ recommended
  - For Kubernetes: at least **2GB RAM per node**, 2 vCPUs minimum
- Sudo privileges

## 1. How to Install Services (`install_services.sh`)

This is the main installation manager. You can use it to pick and choose which tools you want to install.

### Step-by-Step Instructions
1. Clone this repository to your server:
   ```bash
   git clone https://github.com/SuhasLingam/devops.git
   cd devops
   ```
2. Make the scripts executable:
   ```bash
   chmod +x *.sh
   ```
3. Run the installer:
   ```bash
   ./install_services.sh
   ```
4. An interactive menu will appear. Type the number corresponding to the tool you want to install and press Enter.

> **Note on SonarQube**: If you choose Option 3 (SonarQube & PostgreSQL), ensure that the `sonarqube.sh` file is located in the exact same directory where you are running the command.

## 2. How to Manage the Services (`manage_services.sh`)

Once your tools are installed, you can easily stop, start, or check the status of all of them simultaneously using the management script.

### Step-by-Step Instructions
1. Make the management script executable:
   ```bash
   chmod +x manage_services.sh
   ```
2. Run the manager:
   ```bash
   ./manage_services.sh
   ```
3. Use the interactive menu to `Start all services`, `Stop all services`, or `Check status`.

---
## Tool Details & Ports

After installation and startup, access your tools at these default ports:
- **Jenkins**: `http://<your-server-ip>:8080`
- **Tomcat**: `http://<your-server-ip>:8085` *(Changed from default 8080 to prevent conflict with Jenkins)*
- **SonarQube**: `http://<your-server-ip>:9000` (Default Login: `admin` / `admin`)
- **Kubernetes API Server**: `https://<master-ip>:6443` (access via `kubectl` CLI)

## 3. How to Setup Ansible (`ansible_setup.sh`)

This script automates the Master-Node architecture for Ansible on AWS Ubuntu instances.

### Step-by-Step Instructions
1. **On the Node instances**:
   - Run `chmod +x ansible_setup.sh`
   - Run `./ansible_setup.sh` and choose **Option 2 (Node)**.
2. **On the Master instance**:
   - Run `chmod +x ansible_setup.sh`
   - Run `./ansible_setup.sh` and choose **Option 1 (Master)**.
   - Enter the number of nodes and their **Private IPs** when prompted.
   - The script will install Ansible, configure hosts, and establish trust with the nodes.
3. **Verify Connection**:
   - Switch to the devops user: `su - devops`
   - Test connectivity: `ansible all -m ping`

## 4. How to Setup Kubernetes (`k8s_master.sh` / `k8s_node.sh`)

These scripts automate the deployment of a Kubernetes cluster using kubeadm with Docker and CRI-Dockerd as the container runtime.

### Important Notes
- **Order of Operations**: Set up the MASTER first, then WORKER NODES
- **Swap**: Must be disabled (scripts handle this automatically)
- **Unique Hostnames**: Each node should have a unique hostname
- **Resources**: Minimum 2GB RAM and 2 vCPUs per node
- **Network**: Nodes must be able to communicate on all required ports

### Step-by-Step Instructions

1. **On the MASTER node** (Option 6 in `install_services.sh`):
   ```bash
   ./install_services.sh
   # Choose option 6 (Kubernetes - Master Node)
   ```
   Or run directly:
   ```bash
   chmod +x k8s_master.sh
   ./k8s_master.sh
   ```
   This will:
   - Install Docker, CRI-Dockerd, and Kubernetes components
   - Initialize the cluster with `kubeadm init`
   - Set up kubectl for the current user
   - Install Calico networking
   - Save the join command to `kube_join_command.sh`

2. **Copy the join command to worker nodes**:
   ```bash
   scp kube_join_command.sh user@<worker-ip>:~/
   ```

3. **On each WORKER NODE** (Option 7 in `install_services.sh`):
   ```bash
   ./install_services.sh
   # Choose option 7 (Kubernetes - Worker Node)
   ```
   Or run directly:
   ```bash
   chmod +x k8s_node.sh
   ./k8s_node.sh
   ```

4. **Verify the cluster** (on master):
   ```bash
   kubectl get nodes
   ```
   All nodes should show `Ready` status.

### Troubleshooting
- **Nodes stuck in NotReady**: Check `sudo journalctl -u kubelet -f` and verify Calico pods with `kubectl get pods -n kube-system`
- **Join command fails**: Verify network connectivity to master's API server (port 6443), then retry after `sudo kubeadm reset -f`
