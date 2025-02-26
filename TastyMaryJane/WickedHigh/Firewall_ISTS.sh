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

declare -A VM_MANAGEMENT=(
    ["Lockbox"]="SSH"
    ["Safe"]="WinRM"
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

# Allow forwarding between VM bridge (vmbr0) and external network for Proxmox only
iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -A FORWARD -i vmbr0 -o eth0 -s 10.${X_VALUE}.1.5 -j ACCEPT  # Proxmox can go out
iptables -A FORWARD -i eth0 -o vmbr0 -d 10.${X_VALUE}.1.5 -j ACCEPT  # Replies to Proxmox allowed

# Block all outbound traffic from VMs (except allowed inbound services)
for VM in "${!VM_IPS[@]}"; do
    VM_IP=${VM_IPS[$VM]}
    iptables -A FORWARD -s $VM_IP -o eth0 -j DROP  # Block VMs from accessing external network
done

# Allow services for each VM (Inbound traffic only)
for VM in "${!VM_IPS[@]}"; do
    VM_IP=${VM_IPS[$VM]}
    SERVICE=${VM_SERVICES[$VM]}

    echo "Configuring firewall for $VM ($VM_IP) - $SERVICE"

    case $SERVICE in
        "ICMP")
            iptables -A FORWARD -p icmp -d $VM_IP -j ACCEPT
            ;;
        "FTP")
            iptables -A FORWARD -p tcp --dport 21 -d $VM_IP -j ACCEPT
            ;;
        "Telnet")
            iptables -A FORWARD -p tcp --dport 23 -d $VM_IP -j ACCEPT
            ;;
    esac
done

# Allow remote management access (SSH for Lockbox, WinRM for Safe)
for VM in "${!VM_MANAGEMENT[@]}"; do
    VM_IP=${VM_IPS[$VM]}
    MANAGEMENT_SERVICE=${VM_MANAGEMENT[$VM]}

    echo "Allowing remote management for $VM ($VM_IP) - $MANAGEMENT_SERVICE"

    case $MANAGEMENT_SERVICE in
        "SSH")
            iptables -A FORWARD -p tcp --dport 22 -d $VM_IP -j ACCEPT
            ;;
        "WinRM")
            iptables -A FORWARD -p tcp --dport 5985 -d $VM_IP -j ACCEPT  # HTTP WinRM
            iptables -A FORWARD -p tcp --dport 5986 -d $VM_IP -j ACCEPT  # HTTPS WinRM
            ;;
    esac
done

# Harden Proxmox Web GUI access
iptables -A INPUT -p tcp --dport 8006 -s $ADMIN_IP -j ACCEPT
iptables -A INPUT -p tcp --dport 8006 -j DROP

# Block all other inbound traffic to Proxmox
iptables -A INPUT -j DROP

echo "Firewall rules applied successfully!"
