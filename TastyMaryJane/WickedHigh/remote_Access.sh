#!/bin/bash

# Function to check and install required dependencies
check_dependencies() {
    echo "Checking required dependencies..."

    # Check for sshpass (needed for automated SSH authentication)
    if ! command -v sshpass &> /dev/null; then
        echo "sshpass is not installed. Installing..."
        if [[ $(uname) == "Linux" ]]; then
            sudo apt update && sudo apt install -y sshpass  # Debian/Ubuntu
        elif [[ $(uname) == "Darwin" ]]; then
            brew install hudochenkov/sshpass/sshpass  # macOS (Homebrew)
        else
            echo "Unsupported OS. Please install sshpass manually."
            exit 1
        fi
    else
        echo "sshpass is already installed."
    fi

    # Check for telnet (needed for remote access to Windows Nano Server)
    if ! command -v telnet &> /dev/null; then
        echo "Telnet is not installed. Installing..."
        if [[ $(uname) == "Linux" ]]; then
            sudo apt update && sudo apt install -y telnet
        elif [[ $(uname) == "Darwin" ]]; then
            brew install telnet
        else
            echo "Unsupported OS. Please install Telnet manually."
            exit 1
        fi
    else
        echo "Telnet is already installed."
    fi
}

# Run dependency check before anything else
check_dependencies

# Ask for the missing 'X' value in the IP addresses
read -p "Enter the missing 'X' value in the IP addresses (e.g., if IP is 10.X.1.10, enter the X value): " X_VALUE

# Validate input
if ! [[ "$X_VALUE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a numeric value."
    exit 1
fi

# Define IP addresses for remote systems
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

# Function to apply a simple Caesar cipher (shift characters)
caesar_cipher() {
    local text="$1"
    local shift="$2"
    local result=""

    for ((i=0; i<${#text}; i++)); do
        char="${text:i:1}"
        if [[ "$char" =~ [a-zA-Z] ]]; then
            base=65  # Default for uppercase
            [[ "$char" =~ [a-z] ]] && base=97  # If lowercase, adjust base
            
            # Apply shift
            new_char=$(( ( $(printf "%d" "'$char") - base + shift ) % 26 + base ))
            result+=$(printf \\$(printf '%03o' "$new_char"))
        else
            result+="$char"  # Keep non-alphabet characters unchanged
        fi
    done

    echo "$result"
}

# Function to decrypt received messages (reverse Caesar cipher)
decrypt_message() {
    local text="$1"
    local shift="-3"  # Use negative shift to reverse encryption
    caesar_cipher "$text" "$shift"
}

# Function to encrypt messages before sending via Telnet
encrypt_message() {
    local text="$1"
    local shift="3"  # Positive shift for encryption
    caesar_cipher "$text" "$shift"
}

# Function to establish an encrypted Telnet session
telnet_connect() {
    local IP="$1"
    echo "Trying encrypted Telnet connection to $IP..."

    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        echo "Trying user: $USER"

        # Encrypt credentials before sending
        ENCRYPTED_USER=$(encrypt_message "$USER")
        ENCRYPTED_PASS=$(encrypt_message "$PASS")

        # Establish Telnet session and send encrypted credentials
        {
            echo "$ENCRYPTED_USER"
            sleep 1
            echo "$ENCRYPTED_PASS"
            sleep 1
        } | telnet "$IP" | while read -r line; do
            echo "Received (Encrypted): $line"
            DECRYPTED_LINE=$(decrypt_message "$line")
            echo "Decrypted: $DECRYPTED_LINE"
        done

        if [[ $? -eq 0 ]]; then
            echo "Successful encrypted login via Telnet: $USER@$IP"
            return
        fi
    done

    echo "Failed to login via encrypted Telnet on $IP"
}

# Function for interactive encrypted Telnet commands
telnet_interactive() {
    local IP="$1"
    echo "Connected to Windows Nano Server via Telnet with encryption."

    while true; do
        read -p "Encrypted PS> " COMMAND
        if [[ "$COMMAND" == "exit" || "$COMMAND" == "quit" ]]; then
            echo "Exiting encrypted Telnet session..."
            break
        fi
        
        # Encrypt the command before sending
        ENCRYPTED_COMMAND=$(encrypt_message "$COMMAND")
        
        # Send encrypted command via Telnet
        echo "$ENCRYPTED_COMMAND" | telnet "$IP" | while read -r response; do
            DECRYPTED_RESPONSE=$(decrypt_message "$response")
            echo "Decrypted: $DECRYPTED_RESPONSE"
        done
    done
}

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

# Main menu to select which machine to access
while true; do
    echo ""
    echo "Choose a machine to access:"
    echo "1) Proxmox Host ($PROXMOX_IP) [SSH]"
    echo "2) Ubuntu Server ($UBUNTU_IP) [SSH]"
    echo "3) Windows Nano Server ($WINDOWS_NANO_IP) [Encrypted Telnet]"
    echo "4) Exit"
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) ssh_connect "$PROXMOX_IP" ;;
        2) ssh_connect "$UBUNTU_IP" ;;
        3) telnet_interactive "$WINDOWS_NANO_IP" ;;
        4) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice, please try again." ;;
    esac
done
