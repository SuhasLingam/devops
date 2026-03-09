#!/bin/bash
# CAUTION: This script will completely remove Jenkins, Tomcat, SonarQube, and PostgreSQL

echo "=========================================="
echo " Service Uninstallation Script"
echo "=========================================="
echo "WARNING: This will delete ALL services and data!"
read -p "Are you absolutely sure you want to continue? (y/N): " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 1
fi

echo "1. Stopping and Removing SonarQube..."
sudo systemctl stop sonar || true
sudo systemctl disable sonar || true
sudo rm -f /etc/systemd/system/sonar.service
sudo systemctl daemon-reload
sudo rm -rf /opt/sonarqube
sudo userdel ddsonar || true
sudo groupdel ddsonar || true

echo "2. Stopping and Removing Jenkins..."
sudo systemctl stop jenkins || true
sudo systemctl disable jenkins || true
sudo apt-get remove --purge jenkins -y
sudo rm -rf /var/lib/jenkins
sudo rm -rf /var/cache/jenkins
sudo rm -f /etc/default/jenkins

echo "3. Removing Tomcat..."
# Try to find the tomcat directory in common places
TOMCAT_DIR=$(find /home /opt -maxdepth 2 -name "apache-tomcat-*" -type d 2>/dev/null | head -n 1)
if [ -n "$TOMCAT_DIR" ]; then
    echo "Found Tomcat at $TOMCAT_DIR. Removing..."
    # Check if running
    pgrep -f "tomcat" | xargs -r sudo kill -9
    sudo rm -rf "$TOMCAT_DIR"
else
    echo "Tomcat directory not found, skipping..."
fi

echo "4. Removing PostgreSQL..."
sudo systemctl stop postgresql || true
sudo apt-get remove --purge postgresql postgresql-contrib postgresql-common -y
sudo rm -rf /etc/postgresql/
sudo rm -rf /etc/postgresql-common/
sudo rm -rf /var/lib/postgresql/
sudo userdel -r postgres || true
sudo groupdel postgres || true

echo "5. Cleaning up Dependencies (Java, Unzip, etc.)..."
sudo apt-get autoremove -y
sudo apt-get autoclean

echo "=========================================="
echo " Cleanup Complete!"
echo " All services and related data have been removed."
echo "=========================================="
