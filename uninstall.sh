#!/bin/bash

# Define the service name and service path
SERVICE_NAME="pbs_auto.service"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Stop the service if it is running
if systemctl is-active --quiet $SERVICE_NAME; then
  echo "Stopping the service..."
  sudo systemctl stop $SERVICE_NAME
fi

# Disable the service
if systemctl is-enabled --quiet $SERVICE_NAME; then
  echo "Disabling the service..."
  sudo systemctl disable $SERVICE_NAME
fi

# Remove the service file
if [ -f "$SERVICE_PATH" ]; then
  echo "Removing the service file..."
  sudo rm "$SERVICE_PATH"
else
  echo "Service file does not exist."
fi

# Optionally, remove the automation script and .env file
WORKDIR=$(pwd)
AUTOMATION_SCRIPT="$WORKDIR/prx-pbs-auto.sh"
ENV_FILE="$WORKDIR/.env"

if [ -f "$AUTOMATION_SCRIPT" ]; then
  echo "Removing the automation script..."
  rm "$AUTOMATION_SCRIPT"
else
  echo "Automation script does not exist."
fi

if [ -f "$ENV_FILE" ]; then
  echo "Removing the .env file..."
  rm "$ENV_FILE"
else
  echo ".env file does not exist."
fi

# Reload systemd to apply changes
echo "Reloading systemd..."
sudo systemctl daemon-reload

echo "Service removal complete."