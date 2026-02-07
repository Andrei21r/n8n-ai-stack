#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== n8n AI Stack Installer ===${NC}"

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker is not installed. Attempting to install automatically...${NC}"
    
    if [ -f /etc/debian_version ]; then
        # Install Docker on Debian/Ubuntu
        echo -e "${YELLOW}Detected Debian/Ubuntu system.${NC}"
        
        # Remove conflicting packages
        for pkg in docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc; do sudo apt-get remove $pkg; done

        # Update package index
        sudo apt-get update
        sudo apt-get install -y ca-certificates curl gnupg lsof

        # Add Docker's official GPG key
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg

        # Set up the repository
        echo \
          "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker Engine
        sudo apt-get update
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        # Verify installation
        if command -v docker &> /dev/null; then
             echo -e "${GREEN}Docker installed successfully!${NC}"
        else
             echo -e "${RED}Docker installation failed. Please install manually.${NC}"
             exit 1
        fi
    else
        echo -e "${RED}Automatic Docker installation is only supported on Debian/Ubuntu.${NC}"
        echo "Please install Docker manually: https://docs.docker.com/engine/install/"
        exit 1
    fi
fi

# Check if .env exists, if not create with defaults
if [ ! -f .env ]; then
    echo -e "${YELLOW}Creating .env file...${NC}"
    if [ -f .env.example ]; then
        cp .env.example .env
    else
        # Fallback if .env.example is missing
        cat <<EOF > .env
# Domain Configuration
DOMAIN_NAME=
SSL_EMAIL=
GENERIC_TIMEZONE=Europe/Moscow

# Postgres Configuration
POSTGRES_USER=n8n
POSTGRES_PASSWORD=change_this_password
POSTGRES_DB=n8n

# RabbitMQ Configuration
RABBITMQ_USER=user
RABBITMQ_PASSWORD=change_this_password

# n8n Security
N8N_ENCRYPTION_KEY=change_this_to_a_random_string_of_characters
N8N_BASIC_AUTH_ACTIVE=false
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=password

# n8n Execution Data Pruning
EXECUTIONS_DATA_MAX_AGE=72
EXECUTIONS_DATA_PRUNE_INTERVAL=3600
EXECUTIONS_DATA_PRUNE_MAX_COUNT=5000
EOF
    fi
else
    echo -e "${GREEN}.env file already exists.${NC}"
fi

# Function to update .env variable
update_env() {
    local key=$1
    local value=$2
    if grep -q "^${key}=" .env; then
        # Use a different delimiter for sed to handle special chars like /
        sed -i "s|^${key}=.*|${key}=${value}|" .env
    else
        echo "${key}=${value}" >> .env
    fi
}

# Interactive setup
echo -e "\n${YELLOW}Configuration Setup${NC}"
if [ -z "$DOMAIN_NAME" ]; then
    read -p "Enter your domain name for n8n (e.g., n8n.example.com): " DOMAIN_NAME
fi
if [ -z "$SSL_EMAIL" ]; then
    read -p "Enter your email for SSL certificates (e.g., user@example.com): " SSL_EMAIL
fi

if [ -n "$DOMAIN_NAME" ]; then
    update_env "DOMAIN_NAME" "$DOMAIN_NAME"
fi

if [ -n "$SSL_EMAIL" ]; then
    update_env "SSL_EMAIL" "$SSL_EMAIL"
fi

# Generate random passwords if they are still default
CURRENT_POSTGRES_PASS=$(grep "^POSTGRES_PASSWORD=" .env | cut -d '=' -f2)
if [ "$CURRENT_POSTGRES_PASS" == "change_this_password" ]; then
    RAND_PASS=$(openssl rand -hex 16)
    echo -e "${GREEN}Generating secure Postgres password...${NC}"
    update_env "POSTGRES_PASSWORD" "$RAND_PASS"
fi

CURRENT_RABBIT_PASS=$(grep "^RABBITMQ_PASSWORD=" .env | cut -d '=' -f2)
if [ "$CURRENT_RABBIT_PASS" == "change_this_password" ]; then
    RAND_PASS=$(openssl rand -hex 16)
    echo -e "${GREEN}Generating secure RabbitMQ password...${NC}"
    update_env "RABBITMQ_PASSWORD" "$RAND_PASS"
fi

CURRENT_KEY=$(grep "^N8N_ENCRYPTION_KEY=" .env | cut -d '=' -f2)
if [[ "$CURRENT_KEY" == "change_this_to_a_random_string_of_characters" || -z "$CURRENT_KEY" ]]; then
    RAND_KEY=$(openssl rand -hex 24)
    echo -e "${GREEN}Generating n8n encryption key...${NC}"
    update_env "N8N_ENCRYPTION_KEY" "$RAND_KEY"
fi

echo -e "\n${GREEN}Configuration updated!${NC}"

# System Checks
echo -e "\n${YELLOW}Running system checks...${NC}"

# Check Ports
if command -v lsof >/dev/null; then
    if lsof -Pi :80 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${RED}Error: Port 80 is occupied (likely by Apache/Nginx). Please stop the service occupying port 80.${NC}"
        exit 1
    fi
    if lsof -Pi :443 -sTCP:LISTEN -t >/dev/null ; then
        echo -e "${RED}Error: Port 443 is occupied. Please stop the service occupying port 443.${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}lsof not found, skipping port check...${NC}"
fi

# Check/Create Swap
TOTAL_RAM=$(grep MemTotal /proc/meminfo | awk '{print $2}')
if [ "$TOTAL_RAM" -lt 2000000 ]; then
    echo -e "${YELLOW}Low RAM detected (< 2GB). Checking swap...${NC}"
    if [ ! -f /swapfile ]; then
        echo -e "${YELLOW}Creating 2GB Swap file to prevent OOM errors...${NC}"
        sudo fallocate -l 2G /swapfile
        sudo chmod 600 /swapfile
        sudo mkswap /swapfile
        sudo swapon /swapfile
        echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
        echo -e "${GREEN}Swap created successfully.${NC}"
    else
        echo -e "${GREEN}Swap file already exists.${NC}"
    fi
fi

echo -e "Starting services..."

# Create necessary directories
mkdir -p local_files backups

# Start Docker Compose
docker compose up -d

# Enable Docker to start on boot
echo -e "${YELLOW}Enabling Docker to start on boot...${NC}"
if command -v systemctl &> /dev/null; then
    sudo systemctl enable docker
    sudo systemctl enable containerd
    echo -e "${GREEN}Docker service enabled.${NC}"
else
    echo -e "${RED}systemctl not found. Please ensure Docker daemon starts on boot manually.${NC}"
fi

# Setup Unattended Upgrades (Debian/Ubuntu only)
if [ -f /etc/debian_version ]; then
    echo -e "${YELLOW}Setting up automatic OS updates (unattended-upgrades)...${NC}"
    # Non-interactive installation
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get update
    sudo apt-get install -y unattended-upgrades
    
    # Configure 20auto-upgrades to enable daily updates
    echo 'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
APT::Periodic::Unattended-Upgrade "1";' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades > /dev/null

    echo -e "${GREEN}Automatic OS updates enabled.${NC}"
fi

echo -e "\n${GREEN}=== Installation Complete ===${NC}"
echo -e "n8n should be accessible at: https://${DOMAIN_NAME}"
echo -e "RabbitMQ UI: http://<YOUR_SERVER_IP>:15672"
echo -e "Use 'docker compose logs -f' to view logs."
