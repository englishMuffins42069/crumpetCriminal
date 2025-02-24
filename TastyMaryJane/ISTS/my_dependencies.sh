#!/bin/bash

echo "Updating package lists..."
sudo apt update -y

echo "Installing required packages..."
sudo apt install -y sshpass telnet netcat iptables

echo "All necessary packages installed successfully!"
