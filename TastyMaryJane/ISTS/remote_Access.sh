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
    # Ignore empty lines or lines starting with #
    [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue
    CREDENTIALS["$USERNAME"]="$PASSWORD"
done < creds.txt

# Function to attempt SSH connection
ssh_connect() {
    local IP="$1"
    echo "Trying SSH on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        echo "Trying user: $USER"
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$IP" exit
        if [[ $? -eq 0 ]]; then
            echo "Successful login: $USER@$IP"
            sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no "$USER@$IP"
            return
        fi
    done
    echo "Failed to login via SSH on $IP"
}

# Function to attempt Telnet connection
telnet_connect() {
    local IP="$1"
    echo "Trying Telnet on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        echo "Trying user: $USER"
        (echo "$USER"; sleep 1; echo "$PASS"; sleep 1) | telnet "$IP"
        if [[ $? -eq 0 ]]; then
            echo "Successful login via Telnet: $USER@$IP"
            return
        fi
    done
    echo "Failed to login via Telnet on $IP"
}

# Menu to select which machine to access
while true; do
    echo ""
    echo "Choose a machine to access:"
    echo "1) Proxmox Host ($PROXMOX_IP)"
    echo "2) Ubuntu Server ($UBUNTU_IP)"
    echo "3) Windows Nano Server ($WINDOWS_NANO_IP) (Telnet)"
    echo "4) Exit"
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) ssh_connect "$PROXMOX_IP" ;;
        2) ssh_connect "$UBUNTU_IP" ;;
        3) telnet_connect "$WINDOWS_NANO_IP" ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice, please try again." ;;
    esac
done

