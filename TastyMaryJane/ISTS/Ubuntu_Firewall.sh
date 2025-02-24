#!/bin/bash

echo "Configuring iptables Firewall on Ubuntu..."

# Flush existing rules
iptables -F
iptables -X
iptables -Z

# Allow loopback and established traffic
iptables -A INPUT -i lo -j ACCEPT
iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Allow FTP (for scoring engine)
iptables -A INPUT -p tcp --dport 21 -j ACCEPT

# Allow ICMP (Ping)
iptables -A INPUT -p icmp -j ACCEPT

# Block everything else
iptables -A INPUT -j DROP

echo "iptables firewall rules applied!"

