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
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$PBS_HOST" "sudo shutdown now"
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