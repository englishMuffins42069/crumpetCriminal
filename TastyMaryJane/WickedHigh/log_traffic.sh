#!/bin/bash

# Arguments: Protocol, Filter, Proxmox Host
PROTO=$1
FILTER=$2
PROXMOX_HOST=$3
LOG_DIR="$HOME/proxmox_logs"
CONN_LOG_FILE="$LOG_DIR/${PROTO}_connections.log"
CMD_LOG_FILE="$LOG_DIR/${PROTO}_commands.log"
mkdir -p "$LOG_DIR"

declare -A ACTIVE_CONNECTIONS  # Track active Telnet connections

echo "[*] Monitoring $PROTO traffic, logging to $CONN_LOG_FILE and $CMD_LOG_FILE..."

# Capture Telnet traffic with ASCII output (-A) to log typed commands
ssh root@$PROXMOX_HOST "tcpdump -l -i any -A ${FILTER}" | while read -r line; do
    TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")

    # Extract the first IP found in the line (source IP)
    IP=$(echo "$line" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)

    # Log new Telnet connections
    if [[ -n "$IP" && -z "${ACTIVE_CONNECTIONS[$IP]}" ]]; then
        echo "$TIMESTAMP - New Connection: $IP" | tee -a "$CONN_LOG_FILE"
        ACTIVE_CONNECTIONS[$IP]=$TIMESTAMP
    fi

    # Log commands typed in Telnet (filtering out irrelevant TCP headers)
    if echo "$line" | grep -q "login\|password\|sh\|ls\|cd\|cat\|echo\|whoami\|pwd\|netstat\|ping\|rm\|wget\|curl"; then
        echo "$TIMESTAMP - Command: $line" | tee -a "$CMD_LOG_FILE"
    fi

    # Clear inactive connections after 60 seconds
    for key in "${!ACTIVE_CONNECTIONS[@]}"; do
        LAST_SEEN=${ACTIVE_CONNECTIONS[$key]}
        CURRENT_TIME=$(date +"%s")
        LAST_SEEN_TIME=$(date -d "$LAST_SEEN" +"%s")
        if (( CURRENT_TIME - LAST_SEEN_TIME > 60 )); then
            unset ACTIVE_CONNECTIONS[$key]
        fi
    done
done
