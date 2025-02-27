#!/bin/bash

# Function to check and install required dependencies
check_dependencies() {
    echo "Checking required dependencies..."

    # Check for sshpass (needed for automated SSH authentication)
    if ! command -v sshpass &> /dev/null; then
        echo "sshpass is not installed. Installing..."
        if [[ $(uname) == "Linux" ]]; then
            sudo apt update && sudo apt install -y sshpass  # Debian/Ubuntu
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
VAULT_IP="10.${X_VALUE}.1.1"
OFFICE_IP="10.${X_VALUE}.1.2"
TELLER_IP="10.${X_VALUE}.1.3"
ATM_IP="10.${X_VALUE}.1.4"
LOBBY_IP="10.${X_VALUE}.1.5"
CASHROOM_IP="10.${X_VALUE}.1.10"
LOCKBOX_IP="10.${X_VALUE}.1.11"
SAFE_IP="10.${X_VALUE}.1.12"
KOTH_IP="172.29.1.X"
WIRE_IP="192.168.X.1"
EBANKING_IP="192.168.X.2"
ACCOUNTS_IP="192.168.X.3"

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

# Function to establish a Telnet session and enable WinRM
telnet_enable_winrm() {
    local IP="$1"
    echo "Connecting to $IP via Telnet..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        echo "Trying user: $USER"

        {
            echo "$USER"
            sleep 1
            echo "$PASS"
            sleep 1
            echo "winrm quickconfig -q"
            sleep 2
            echo "exit"
        } | telnet "$IP"

        if [[ $? -eq 0 ]]; then
            echo "WinRM enabled successfully on $IP."
            return
        fi
    done
    echo "Failed to enable WinRM on $IP via Telnet."
}

# Function to attempt SSH connection
ssh_connect() {
    local IP="$1"
    echo "Trying SSH on $IP..."
    for USER in "${!CREDENTIALS[@]}"; do
        PASS="${CREDENTIALS[$USER]}"
        echo "Trying user: $USER"
        sshpass -p "$PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$USER@$IP"
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
    echo "1) Vault ($VAULT_IP) [SSH]"
    echo "2) Office ($OFFICE_IP) [SSH]"
    echo "3) Teller ($TELLER_IP) [SSH]"
    echo "4) ATM ($ATM_IP) [SSH]"
    echo "5) Lobby ($LOBBY_IP) [SSH]"
    echo "6) Cashroom ($CASHROOM_IP) [SSH]"
    echo "7) Lockbox ($LOCKBOX_IP) [SSH]"
    echo "8) Safe ($SAFE_IP) [Telnet to enable WinRM]"
    echo "9) Wire ($WIRE_IP) [SSH]"
    echo "10) EBanking ($EBANKING_IP) [SSH]"
    echo "11) Accounts ($ACCOUNTS_IP) [SSH]"
    echo "12) Exit"
    read -p "Enter your choice: " CHOICE

    case $CHOICE in
        1) ssh_connect "$VAULT_IP" ;;
        2) ssh_connect "$OFFICE_IP" ;;
        3) ssh_connect "$TELLER_IP" ;;
        4) ssh_connect "$ATM_IP" ;;
        5) ssh_connect "$LOBBY_IP" ;;
        6) ssh_connect "$CASHROOM_IP" ;;
        7) ssh_connect "$LOCKBOX_IP" ;;
        8) telnet_enable_winrm "$SAFE_IP" ;;
        9) ssh_connect "$WIRE_IP" ;;
        10) ssh_connect "$EBANKING_IP" ;;
        11) ssh_connect "$ACCOUNTS_IP" ;;
        12) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid choice, please try again." ;;
    esac
done
