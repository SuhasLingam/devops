#!/bin/bash
set -e # Exit immediately if a command fails

echo "=========================================="
echo " Service Installation Manager"
echo "=========================================="
echo "Which service would you like to install?"
echo "------------------------------------------"
echo "1) Jenkins"
echo "2) Tomcat (Port 8085)"
echo "3) SonarQube & PostgreSQL"
echo "4) Exit"
echo "=========================================="
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "Starting Jenkins deployment..."
        wget -q https://raw.githubusercontent.com/akshu20791/Deployment-script/refs/heads/main/jenkins.sh -O jenkins.sh
        chmod +x jenkins.sh
        sudo ./jenkins.sh
        
        # Automate the sudoers configuration (no manual visudo needed!)
        echo "jenkins ALL=(ALL:ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/jenkins > /dev/null
        sudo chmod 440 /etc/sudoers.d/jenkins
        
        sudo systemctl restart jenkins
        echo "Jenkins installed and sudoers configured successfully!"
        ;;
    2)
        echo "Starting Tomcat deployment..."
        sudo apt update
        sudo apt install unzip -y
        
        # Download and extract Tomcat
        wget https://dlcdn.apache.org/tomcat/tomcat-9/v9.0.115/bin/apache-tomcat-9.0.115.zip
        unzip -q apache-tomcat-9.0.115.zip
        
        # Clean up the zip file to save space
        rm apache-tomcat-9.0.115.zip
        
        # Navigate to Tomcat config and change port to 8085 to avoid Jenkins conflict
        cd apache-tomcat-9.0.115/conf/
        sed -i 's/port="8080"/port="8085"/g' server.xml
        
        # Make scripts executable and start Tomcat
        cd ../bin
        sudo chmod +x *.sh
        ./startup.sh
        
        echo "Tomcat deployed successfully on port 8085!"
        ;;
    3)
        echo "Starting SonarQube & PostgreSQL deployment..."
        if [ -f "./sonarqube.sh" ]; then
            chmod +x ./sonarqube.sh
            ./sonarqube.sh
            echo "SonarQube deployment script executed successfully!"
        else
            echo "Error: sonarqube.sh script not found in the current directory."
            echo "Please make sure sonarqube.sh is downloaded and available."
            exit 1
        fi
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
