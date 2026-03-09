#!/bin/bash

# Define the services
SERVICES=("jenkins" "tomcat" "sonar" "postgresql")

echo "=========================================="
echo " Service Management Script"
echo "=========================================="
echo "Available Services: Jenkins, Tomcat, SonarQube, PostgreSQL"
echo "------------------------------------------"
echo "Options:"
echo "1) Stop all services"
echo "2) Start all services"
echo "3) Start a specific service"
echo "4) Check status of all services"
echo "5) Exit"
echo "=========================================="

read -p "Enter your choice (1-5): " choice

case $choice in
    1)
        echo "Stopping all services..."
        for service in "${SERVICES[@]}"; do
            # Tomcat doesn't use a standard systemd service in your current setup, it uses startup.sh/shutdown.sh
            if [ "$service" == "tomcat" ]; then
                if [ -f "/opt/apache-tomcat-9.0.115/bin/shutdown.sh" ]; then
                    echo "Stopping Tomcat..."
                    sudo /opt/apache-tomcat-9.0.115/bin/shutdown.sh
                elif [ -f "$(pwd)/apache-tomcat-9.0.115/bin/shutdown.sh" ]; then
                    echo "Stopping Tomcat..."
                    sudo $(pwd)/apache-tomcat-9.0.115/bin/shutdown.sh
                else
                    echo "Tomcat shutdown script not found."
                fi
            else
                echo "Stopping $service..."
                sudo systemctl stop $service || echo "Failed to stop $service (might not be installed or running)"
            fi
        done
        echo "All target services stopped."
        ;;
    2)
        echo "Starting all services..."
        for service in "${SERVICES[@]}"; do
            if [ "$service" == "tomcat" ]; then
                if [ -f "/opt/apache-tomcat-9.0.115/bin/startup.sh" ]; then
                    echo "Starting Tomcat..."
                    sudo /opt/apache-tomcat-9.0.115/bin/startup.sh
                elif [ -f "$(pwd)/apache-tomcat-9.0.115/bin/startup.sh" ]; then
                    echo "Starting Tomcat..."
                    sudo $(pwd)/apache-tomcat-9.0.115/bin/startup.sh
                else
                    echo "Tomcat startup script not found."
                fi
            else
                echo "Starting $service..."
                sudo systemctl start $service
                sudo systemctl status $service --no-pager
            fi
        done
        echo "All target services started."
        ;;
    3)
        read -p "Enter the name of the service to start (jenkins, tomcat, sonar, postgresql): " start_service
        # Convert to lowercase
        start_service=$(echo "$start_service" | tr '[:upper:]' '[:lower:]')
        
        if [ "$start_service" == "tomcat" ]; then
            if [ -f "/opt/apache-tomcat-9.0.115/bin/startup.sh" ]; then
                echo "Starting Tomcat..."
                sudo /opt/apache-tomcat-9.0.115/bin/startup.sh
            elif [ -f "$(pwd)/apache-tomcat-9.0.115/bin/startup.sh" ]; then
                echo "Starting Tomcat..."
                sudo $(pwd)/apache-tomcat-9.0.115/bin/startup.sh
            else
                echo "Tomcat startup script not found."
            fi
        elif [[ " ${SERVICES[@]} " =~ " ${start_service} " ]]; then
            echo "Starting $start_service..."
            sudo systemctl start $start_service
            sudo systemctl status $start_service --no-pager
        else
            echo "Invalid service name. Allowed values: jenkins, tomcat, sonar, postgresql"
        fi
        ;;
    4)
        echo "Checking status of all services..."
        echo "------------------------------------------"
        for service in "${SERVICES[@]}"; do
            if [ "$service" == "tomcat" ]; then
               # Basic check to see if Java is running a Tomcat process
               if pgrep -f "tomcat" > /dev/null; then
                   echo "tomcat: active (running)"
               else
                   echo "tomcat: inactive (dead)"
               fi
            else
               status=$(systemctl is-active $service 2>/dev/null || echo "not installed")
               echo "$service: $status"
            fi
        done
        ;;
    5)
        echo "Exiting..."
        exit 0
        ;;
    *)
        echo "Invalid choice. Exiting..."
        exit 1
        ;;
esac
