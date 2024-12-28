# Function to turn on the PBS server
turn_on_server() {
  ipmitool -I lanplus -H "$IPMI_HOST" -U "$IPMI_USER" -P "$IPMI_PASS" chassis power on
}

# Function to shut down the PBS server over SSH
turn_off_server() {
  sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no "$SSH_USER@$PBS_HOST" "sudo shutdown now"
}

# Ask the user if they want to start or stop the server
echo "Do you want to start or stop the server? (start/stop)"
read -r action
if [ "$action" = "start" ]; then
    turn_on_server
elif [ "$action" = "stop" ]; then
    turn_off_server
else
    echo "Invalid action. Please enter 'start' or 'stop'."
    exit 1
fi
