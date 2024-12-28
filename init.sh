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
REMOTE_SERVER=your_remote_server_ip
SCHEDULE_DAYS=
POWER_ON_TIME=
DURATION=
EOL
  echo "Please edit the .env file with your IPMI and SSH credentials."
else
  echo ".env file already exists."
fi

# Function to get user input for power schedule
get_power_schedule() {
  echo "Select power schedule:"
  echo "1) Weekly"
  echo "2) Biweekly"
  echo "3) Monthly"
  echo "4) Bimonthly"
  read -p "Enter your choice (1-4): " schedule_choice

  read -p "Enter the day(s) to run (e.g., 1 for Monday, 7 for Sunday): " days
  read -p "Enter the time to power on the server (HH:MM): " power_on_time
  read -p "Enter the duration to keep the server on (in minutes): " duration

  # Save the schedule details to .env
  echo "SCHEDULE_DAYS=$days" >> "$WORKDIR/.env"
  echo "POWER_ON_TIME=$power_on_time" >> "$WORKDIR/.env"
  echo "DURATION=$duration" >> "$WORKDIR/.env"
}

get_power_schedule

# Create the automation script
cat <<'EOL' > "$WORKDIR/backup_auto.sh"
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
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$REMOTE_SERVER" "sudo -S shutdown now"
}

# Calculate shutdown time
shutdown_time=$(date -d "$POWER_ON_TIME + $DURATION minutes" +"%H:%M")

# Continuous loop to check the time
while true; do
  current_time=$(date +"%H:%M")
  current_day=$(date +"%u")  # 7 is Sunday

  # Check if the current day is in the specified days
  if [[ $SCHEDULE_DAYS == *"$current_day"* ]]; then
    # Turn on at specified time
    if [ "$current_time" == "$POWER_ON_TIME" ]; then
      echo "Turning on server..."
      turn_on_server
      sleep 90
    # Shut down at calculated shutdown time
    elif [ "$current_time" == "$shutdown_time" ]; then
      echo "Shutting down server..."
      turn_off_server
      sleep 90
    fi
  fi
  sleep 60
done
EOL

# Make the automation script executable
chmod +x "$WORKDIR/backup_auto.sh"

# Create the systemd service file
SERVICE_PATH="/etc/systemd/system/backup_auto.service"
if [ ! -f "$SERVICE_PATH" ]; then
  echo "Creating systemd service for automatic startup..."

  sudo tee "$SERVICE_PATH" > /dev/null <<EOL
[Unit]
Description=Automate remote server power cycle
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash $WORKDIR/backup_auto.sh
WorkingDirectory=$WORKDIR
EnvironmentFile=$WORKDIR/.env
Restart=always

[Install]
WantedBy=multi-user.target
EOL

  # Enable and start the service
  sudo systemctl daemon-reload
  sudo systemctl enable backup_auto.service
  sudo systemctl start backup_auto.service

  echo "Service created, enabled, and started. It will now run in the background on system startup."
else
  echo "Service already exists. Restarting the service..."
  sudo systemctl restart backup_auto.service
fi

echo "Initialization complete."