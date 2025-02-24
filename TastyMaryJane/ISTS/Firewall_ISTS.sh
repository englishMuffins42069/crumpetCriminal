#!/bin/bash

# Ask for the missing 'X' value in the IP addresses
read -p "Enter the missing 'X' value in the IP addresses (e.g., if IP is 10.X.1.10, enter the X value): " X_VALUE

# Validate input
if ! [[ "$X_VALUE" =~ ^[0-9]+$ ]]; then
    echo "Invalid input. Please enter a numeric value."
    exit 1
fi

# Ask for the admin IP
read -p "Enter your personal IP for Proxmox Web GUI access: " ADMIN_IP

# Define VM IPs dynamically based on user input
declare -A VM_IPS=(
    ["TempleOS"]="10.${X_VALUE}.1.10"
    ["Lockbox"]="10.${X_VALUE}.1.11"
    ["Safe"]="10.${X_VALUE}.1.12"
)

declare -A VM_SERVICES=(
    ["TempleOS"]="ICMP"
    ["Lockbox"]="FTP"
    ["Safe"]="Telnet"
)

echo "Applying firewall rules..."

# Flush existing rules
iptables -F
iptables -X

# Enable IP forwarding in the kernel
echo "Enabling IP forwarding..."
sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward = 1" | tee -a /etc/sysctl.conf

# Allow loopback and established traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow Proxmox (10.X.1.5) to communicate with all VMs
iptables -A FORWARD -s 10.${X_VALUE}.1.5 -d 10.${X_VALUE}.1.0/24 -j ACCEPT
iptables -A FORWARD -s 10.${X_VALUE}.1.0/24 -d 10.${X_VALUE}.1.5 -j ACCEPT

# Allow forwarding between VM bridge (vmbr0) and external network
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i vmbr0 -o eth0 -j ACCEPT
iptables -A FORWARD -i eth0 -o vmbr0 -j ACCEPT

# Allow services for each VM (use FORWARD instead of INPUT)
for VM in "${!VM_IPS[@]}"; do
    VM_IP=${VM_IPS[$VM]}
    SERVICE=${VM_SERVICES[$VM]}

    echo "Configuring firewall for $VM ($VM_IP) - $SERVICE"

    case $SERVICE in
        "ICMP")
            iptables -A FORWARD -p icmp -s $VM_IP -j ACCEPT
            ;;
        "FTP")
            iptables -A FORWARD -p tcp --dport 21 -s $VM_IP -j ACCEPT
            ;;
        "Telnet")
            iptables -A FORWARD -p tcp --dport 23 -s $VM_IP -j ACCEPT
            ;;
    esac
done

# Harden Proxmox Web GUI access
iptables -A INPUT -p tcp --dport 8006 -s $ADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 8006 -j DROP

# Block all other inbound traffic to Proxmox
iptables -A INPUT -j DROP

echo "Firewall rules applied successfully!"

