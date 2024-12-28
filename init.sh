#!/bin/bash

# Install ipmitool if not already installed
if ! command -v ipmitool &> /dev/null; then
  echo "Installing ipmitool..."
  sudo apt update && sudo apt install -y ipmitool
else
  echo "ipmitool is already installed."
fi

# Install sshpass if not already installed
if ! command -v sshpass &> /dev/null; then
  echo "Installing sshpass..."
  sudo apt update && sudo apt install -y sshpass
else
  echo "sshpass is already installed."
fi

# Set the working directory
WORKDIR=$(pwd)

# Create .env file if it doesn't exist
if [ ! -f "$WORKDIR/.env" ]; then
  echo "Creating .env file..."
  cat <<EOL > "$WORKDIR/.env"
IPMI_HOST=your_server_ip
IPMI_USER=your_ipmi_username
IPMI_PASS=your_ipmi_password
SSH_USER=your_ssh_username
SSH_PASS=your_ssh_password
PBS_HOST=your_ssh_ip
EOL
  echo "Please edit the .env file with your IPMI and SSH credentials."
else
  echo ".env file already exists."
fi

# Create the automation script
cat <<'EOL' > "$WORKDIR/pbs_auto.sh"
#!/bin/bash

# Load .env file
if [ -f .env ]; then
  export $(cat .env | xargs)
else
  echo ".env file not found"
  exit 1
fi

# Function to turn on the PBS server
turn_on_server() {
  ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" chassis power on
}

# Function to shut down the PBS server over SSH
turn_off_server() {
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$IPMI_HOST" "sudo shutdown now"
}

# Continuous loop to check the time
while true; do
  current_time=$(date +"%H:%M")
  current_day=$(date +"%u")  # 7 is Sunday

  # Turn on at 00:30 and off at 02:00 on Sunday
  if [ "$current_day" -eq 7 ] && [ "$current_time" == "00:30" ]; then
    echo "Turning on server..."
    turn_on_server
    sleep 90
  elif [ "$current_day" -eq 7 ] && [ "$current_time" == "02:00" ]; then
    echo "Shutting down server..."
    turn_off_server
    sleep 90
  fi
  sleep 60
done
EOL

# Make the automation script executable
chmod +x "$WORKDIR/pbs_auto.sh"

# Create the systemd service file
SERVICE_PATH="/etc/systemd/system/pbs_auto.service"
if [ ! -f "$SERVICE_PATH" ]; then
  echo "Creating systemd service for automatic startup..."

  sudo tee "$SERVICE_PATH" > /dev/null <<EOL
[Unit]
Description=Automate PBS server power cycle
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $WORKDIR/pbs_auto.sh
WorkingDirectory=$WORKDIR
EnvironmentFile=$WORKDIR/.env
Restart=always

[Install]
WantedBy=multi-user.target
EOL

  # Enable and start the service
  sudo systemctl daemon-reload
  sudo systemctl enable pbs_auto.service
  sudo systemctl start pbs_auto.service

  echo "Service created, enabled, and started. It will now run in the background on system startup."
else
  echo "Service already exists. Restarting the service..."
  sudo systemctl restart pbs_auto.service
fi

echo "Initialization complete."