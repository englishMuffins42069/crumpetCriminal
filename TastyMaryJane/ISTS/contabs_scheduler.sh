#!/bin/bash

# Ask for the missing 'X' value in the IP addresses
read -p "Enter the missing 'X' value in the IP addresses (e.g., if IP is 10.X.1.10, enter the X value): " X_VALUE

# Validate input
if ! [[ "$X_VALUE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a numeric value."
    exit 1
fi

# Define IPs dynamically
PROXMOX_IP="10.${X_VALUE}.1.5"
UBUNTU_IP="10.${X_VALUE}.1.11"
WINDOWS_NANO_IP="10.${X_VALUE}.1.12"

# Check if creds.txt exists
if [[ ! -f "creds.txt" ]]; then
    echo "Error: creds.txt file not found!"
    exit 1
fi

# Load credentials into an array
declare -A CREDENTIALS
while IFS=, read -r USERNAME PASSWORD; do
    [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue
    CREDENTIALS["$USERNAME"]="$PASSWORD"
done < creds.txt

# Function to print crontabs for Proxmox and Ubuntu
print_crontabs() {
    local IP="$1"
    echo "Checking crontabs on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER@$IP" "echo '--- Crontabs for $USER ---'; sudo crontab -l -u $USER"
    done
}

# Function to delete all scheduled tasks in Windows Nano Server
delete_windows_tasks() {
    echo "Deleting all scheduled tasks on Windows Nano Server ($WINDOWS_NANO_IP)..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        (echo "$USER"; sleep 1; echo "$PASS"; sleep 1; echo "powershell.exe Get-ScheduledTask | Where-Object { \$_.TaskName -ne 'Powershell' } | ForEach-Object { Unregister-ScheduledTask -TaskName \$_.TaskName -Confirm:\$false }"; sleep 1) | telnet "$WINDOWS_NANO_IP"
        if [[ $? -eq 0 ]]; then
            echo "Scheduled tasks deleted successfully on $WINDOWS_NANO_IP"
            return
        fi
    done
    echo "Failed to delete tasks on Windows Nano Server."
}

# Execute functions
print_crontabs "$PROXMOX_IP"
print_crontabs "$UBUNTU_IP"
delete_windows_tasks

echo "Hardening script executed successfully!"
