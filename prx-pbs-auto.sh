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
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$PBS_HOST" "sudo -S shutdown now"
}

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

  # Calculate shutdown time
  shutdown_time=$(date -d "$power_on_time + $duration minutes" +"%H:%M")
}

# Get the power schedule from the user
get_power_schedule

# Continuous loop to check the time
while true; do
  current_time=$(date +"%H:%M")
  current_day=$(date +"%u")  # 7 is Sunday

  # Check if the current day is in the specified days
  if [[ $days == *"$current_day"* ]]; then
    # Turn on at specified time
    if [ "$current_time" == "$power_on_time" ]; then
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