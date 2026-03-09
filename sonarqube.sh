#!/bin/bash
set -e # Exit immediately if a command fails

echo "=========================================="
echo " Starting SonarQube Installation Script"
echo "=========================================="

echo "1. Updating and upgrading the server..."
sudo apt update
sudo apt upgrade -y

echo "2. Installing OpenJDK 17..."
sudo apt install -y openjdk-17-jdk

echo "3. Installing and Configuring PostgreSQL..."
# Add PostgreSQL repo
sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'

# Add PostgreSQL signing key
wget -q https://www.postgresql.org/media/keys/ACCC4CF8.asc -O - | sudo apt-key add -

# Install PostgreSQL
sudo apt install postgresql postgresql-contrib -y

# Enable and start PostgreSQL service
sudo systemctl enable postgresql
sudo systemctl start postgresql

echo "   Creating SonarQube database and user..."
# Wait for postgres to be ready
sleep 2

# Create user, assign password, create database, and grant privileges non-interactively
sudo -u postgres psql -c "CREATE USER ddsonar WITH ENCRYPTED PASSWORD 'mwd#2%#!!#%rgs';"
sudo -u postgres psql -c "CREATE DATABASE ddsonarqube OWNER ddsonar;"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE ddsonarqube TO ddsonar;"

echo "4. Downloading and Installing SonarQube..."
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

echo "5. Adding SonarQube Group and User..."
sudo groupadd ddsonar || true # ignore if already exists
sudo useradd -d /opt/sonarqube -g ddsonar ddsonar || true # ignore if already exists
sudo chown -R ddsonar:ddsonar /opt/sonarqube

echo "6. Configuring SonarQube database connection..."
SONAR_PROPS="/opt/sonarqube/conf/sonar.properties"

# Uncomment and set username and password using sed
sudo sed -i 's/#sonar.jdbc.username=/sonar.jdbc.username=ddsonar/g' $SONAR_PROPS
sudo sed -i 's/#sonar.jdbc.password=/sonar.jdbc.password=mwd#2%#!!#%rgs/g' $SONAR_PROPS

# Append the JDBC URL to the properties file
echo "sonar.jdbc.url=jdbc:postgresql://localhost:5432/ddsonarqube" | sudo tee -a $SONAR_PROPS > /dev/null

# Configure the sonar execution script
SONAR_SH="/opt/sonarqube/bin/linux-x86-64/sonar.sh"
sudo sed -i 's/#RUN_AS_USER=/RUN_AS_USER=ddsonar/g' $SONAR_SH

echo "7. Setting up Systemd service..."
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

echo "8. Modifying Kernel System Limits for Elasticsearch..."
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf > /dev/null
echo "fs.file-max=65536" | sudo tee -a /etc/sysctl.conf > /dev/null

# Apply the kernel changes immediately without needing a reboot
sudo sysctl -p

echo "9. Starting SonarQube Service..."
sudo systemctl start sonar

echo "=========================================="
echo " Installation Complete!"
echo " SonarQube is now starting up. This may take a few minutes."
echo " Access the Web Interface at: http://<your_server_ip>:9000"
echo " "
echo " Default Login Credentials:"
echo " Username: admin"
echo " Password: admin"
echo "=========================================="
