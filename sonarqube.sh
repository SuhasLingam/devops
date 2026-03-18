#!/bin/bash
set -e # Exit immediately if a command fails

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

echo "=========================================="
echo " Starting SonarQube Installation Script"
echo "=========================================="

log_info "1. Updating and upgrading the server..."
sudo apt update
sudo apt upgrade -y

log_info "2. Installing OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

# Force Java 17 as the default so it doesn't conflict with Java 21 (from Jenkins)
sudo update-alternatives --set java /usr/lib/jvm/java-17-openjdk-amd64/bin/java || log_warn "Could not set Java 17 as default automatically. Please check manually."

log_info "3. Installing and Configuring PostgreSQL..."
# Add PostgreSQL repo
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Add PostgreSQL signing key
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Enable and start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql

log_info "   Creating SonarQube database and user..."
# Wait for postgres to be ready
sleep 2

# Create user, assign password, create database, and grant privileges non-interactively
sudo -u postgres psql -c "CREATE USER ddsonar WITH ENCRYPTED PASSWORD 'mwd#2%#!!#%rgs';"
sudo -u postgres psql -c "CREATE DATABASE ddsonarqube OWNER ddsonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ddsonarqube TO ddsonar;"

log_info "4. Downloading and Installing SonarQube..."
sudo apt install zip -y

# Clean up any previous incomplete installation
sudo rm -rf /opt/sonarqube
sudo rm -rf /opt/sonarqube-10.0.0.68432

# Download SonarQube (v10.0.0.68432 as per the guide)
sudo wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-10.0.0.68432.zip -O /tmp/sonarqube.zip

# Unzip and move to /opt
sudo unzip -q /tmp/sonarqube.zip -d /opt/
sudo mv /opt/sonarqube-10.0.0.68432 /opt/sonarqube

# Clean up the zip file
sudo rm /tmp/sonarqube.zip

log_info "5. Adding SonarQube Group and User..."
sudo groupadd ddsonar || true # ignore if already exists
sudo useradd -d /opt/sonarqube -g ddsonar ddsonar || true # ignore if already exists
sudo chown -R ddsonar:ddsonar /opt/sonarqube

log_info "6. Configuring SonarQube database connection..."
SONAR_PROPS="/opt/sonarqube/conf/sonar.properties"

# Uncomment and set username and password using sed
sudo sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=ddsonar/g' $SONAR_PROPS
sudo sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=mwd#2%#!!#%rgs/g' $SONAR_PROPS

# Append the JDBC URL to the properties file
echo "sonar.jdbc.url=jdbc:postgresql://localhost:5432/ddsonarqube" | sudo tee -a $SONAR_PROPS > /dev/null

# Configure the sonar execution script
SONAR_SH="/opt/sonarqube/bin/linux-x86-64/sonar.sh"
sudo sed -i 's/#RUN_AS_USER=/RUN_AS_USER=ddsonar/g' $SONAR_SH

log_info "7. Setting up Systemd service..."
cat <<EOF | sudo tee /etc/systemd/system/sonar.service > /dev/null
[Unit]
Description=SonarQube service
After=syslog.target network.target

[Service]
Type=forking
ExecStart=/opt/sonarqube/bin/linux-x86-64/sonar.sh start
ExecStop=/opt/sonarqube/bin/linux-x86-64/sonar.sh stop
User=ddsonar
Group=ddsonar
Restart=always
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd and enable sonar service
sudo systemctl daemon-reload
sudo systemctl enable sonar

log_info "8. Modifying Kernel System Limits for Elasticsearch..."
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf > /dev/null

# Apply the kernel changes immediately without needing a reboot
sudo sysctl -p

# Clear out any stale temp/data files before the first startup
sudo rm -rf /opt/sonarqube/temp/*
sudo rm -rf /opt/sonarqube/data/*

log_info "9. Starting SonarQube Service..."
sudo systemctl start sonar

echo "=========================================="
log_info " Installation Complete!"
log_info " SonarQube is now starting up. This may take a few minutes."
log_info " Access the Web Interface at: http://<your_server_ip>:9000"
echo " "
log_info " Default Login Credentials:"
log_info " Username: admin"
log_info " Password: admin"
echo "=========================================="
