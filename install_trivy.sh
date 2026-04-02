#!/bin/bash
# Trivy Installation Script for Ubuntu
# Reference: https://aquasecurity.github.io/trivy/v0.55/getting-started/installation/

echo "Installing Trivy dependencies..."
sudo apt-get update
sudo apt-get install -y wget apt-transport-https gnupg

echo "Adding Trivy repository key..."
wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | gpg --dearmor | sudo tee /usr/share/keyrings/trivy.gpg > /dev/null

echo "Adding Trivy repository..."
echo "deb [signed-by=/usr/share/keyrings/trivy.gpg] https://aquasecurity.github.io/trivy-repo/deb generic main" | sudo tee -a /etc/apt/sources.list.d/trivy.list

echo "Updating package list..."
sudo apt-get update

echo "Installing Trivy..."
sudo apt-get install -y trivy

echo "Verifying Trivy installation..."
trivy --version

echo "Trivy installation completed successfully!"