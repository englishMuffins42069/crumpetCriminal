# Allow Telnet (for scoring engine)
New-NetFirewallRule -DisplayName "Allow Telnet" -Direction Inbound -LocalPort 23 -Protocol TCP -Action Allow -RemoteAddress Any

# Allow ICMP (Ping)
New-NetFirewallRule -DisplayName "Allow ICMP (Ping)" -Direction Inbound -Protocol ICMPv4 -Action Allow -RemoteAddress Any

# Block all other inbound traffic
New-NetFirewallRule -DisplayName "Block All Other Traffic" -Direction Inbound -Action Block

Write-Host "Nano Server firewall rules applied!"

