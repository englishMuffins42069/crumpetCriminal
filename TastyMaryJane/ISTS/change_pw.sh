#!/bin/bash

# Ask for the new password
read -s -p "Enter the new password for all users: " NEW_PASSWORD
echo ""
read -s -p "Confirm the new password: " CONFIRM_PASSWORD
echo ""

# Check if passwords match
if [[ "$NEW_PASSWORD" != "$CONFIRM_PASSWORD" ]]; then
    echo "Error: Passwords do not match!"
    exit 1
fi

# Check if creds.txt exists
if [[ ! -f "creds.txt" ]]; then
    echo "Error: creds.txt file not found!"
    exit 1
fi

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

# Backup old creds.txt
cp creds.txt creds_backup.txt

# Update creds.txt with new passwords
echo "Updating creds.txt with new passwords..."
while IFS=, read -r USERNAME OLD_PASSWORD; do
    # Ignore empty lines or lines starting with #
    [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue
    echo "$USERNAME,$NEW_PASSWORD"
done < creds_backup.txt > creds.txt

echo "Password file updated."

# Load new credentials into an array
declare -A CREDENTIALS
while IFS=, read -r USERNAME PASSWORD; do
    [[ -z "$USERNAME" || "$USERNAME" =~ ^# ]] && continue
    CREDENTIALS["$USERNAME"]="$PASSWORD"
done < creds.txt

# Function to change passwords on Linux (Proxmox & Ubuntu)
change_linux_password() {
    local IP="$1"
    echo "Updating passwords on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        OLD_PASS="${CREDENTIALS[$USER]}"
        sshpass -p "$OLD_PASS" ssh -o StrictHostKeyChecking=no "$USER@$IP" "echo -e \"$NEW_PASSWORD\n$NEW_PASSWORD\" | sudo passwd $USER"
        if [[ $? -eq 0 ]]; then
            echo "Password changed successfully for $USER on $IP"
        else
            echo "Failed to update password for $USER on $IP"
        fi
    done
}

# Function to change password on Windows Nano Server via Telnet
change_windows_password() {
    local IP="$1"
    echo "Updating passwords on Windows Nano Server ($IP)..."
    for USER in "${!CREDENTIALS[@]}"; do
        OLD_PASS="${CREDENTIALS[$USER]}"
        (echo "$USER"; sleep 1; echo "$OLD_PASS"; sleep 1; echo "net user $USER $NEW_PASSWORD"; sleep 1) | telnet "$IP"
        if [[ $? -eq 0 ]]; then
            echo "Password changed successfully for $USER on $IP"
        else
            echo "Failed to update password for $USER on $IP"
        fi
    done
}

# Change passwords on all systems
change_linux_password "$PROXMOX_IP"
change_linux_password "$UBUNTU_IP"
change_windows_password "$WINDOWS_NANO_IP"

echo "All passwords updated successfully!"
