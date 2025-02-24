#!/bin/bash

# Ask for the missing 'X' value in the IP addresses
read -p "Enter the missing 'X' value in the IP addresses (e.g., if IP is 10.X.1.10, enter the X value): " X_VALUE

# Validate input
if ! [[ "$X_VALUE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a numeric value."
    exit 1
fi

# Define IP addresses dynamically
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

# Function to list users on Linux (Proxmox & Ubuntu)
list_linux_users() {
    local IP="$1"
    echo "Checking users on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER@$IP" "echo '--- Users on $IP ---'; cut -d: -f1 /etc/passwd | sort"
        if [[ $? -eq 0 ]]; then
            return
        fi
    done
    echo "Failed to retrieve users from $IP"
}

# Function to list users on Windows Nano Server via Telnet
list_windows_users() {
    echo "Checking users on Windows Nano Server ($WINDOWS_NANO_IP)..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        (echo "$USER"; sleep 1; echo "$PASS"; sleep 1; echo "net user"; sleep 1) | telnet "$WINDOWS_NANO_IP"
        if [[ $? -eq 0 ]]; then
            return
        fi
    done
    echo "Failed to retrieve users from Windows Nano Server."
}

# Execute functions
list_linux_users "$PROXMOX_IP"
list_linux_users "$UBUNTU_IP"
list_windows_users

echo "User check complete!"
