#!/bin/bash

# Function to backup all VMs and Containers
backup_vms_containers() {
    echo "Enter the backup directory path (must exist):"
    read -r BACKUP_DIR

    # Ensure directory exists
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "Error: Directory does not exist. Please create it first."
        exit 1
    fi

    echo "Backing up all VMs and Containers to $BACKUP_DIR..."

    # Backup all VMs
    for vmid in $(qm list | awk 'NR>1 {print $1}'); do
        echo "Backing up VM $vmid..."
        vzdump $vmid --dumpdir "$BACKUP_DIR" --mode snapshot || echo "❌ Failed to backup VM $vmid"
    done

    # Backup all Containers (LXC)
    for ct_id in $(pct list | awk 'NR>1 {print $1}'); do
        echo "Backing up Container $ct_id..."
        vzdump $ct_id --dumpdir "$BACKUP_DIR" --mode snapshot || echo "❌ Failed to backup Container $ct_id"
    done

    echo "✅ Backup completed successfully!"
}

# Function to restore a VM or Container from backup
restore_vms_containers() {
    echo "Enter the backup directory where your backups are stored:"
    read -r BACKUP_DIR

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ Error: Directory does not exist. Please enter a valid backup directory."
        exit 1
    fi

    echo "📂 Available backups in $BACKUP_DIR:"
    ls -lh "$BACKUP_DIR" | grep "vzdump" | awk '{print NR") "$9}'

    echo "Enter the number of the backup file you want to restore:"
    read -r FILE_NUM

    BACKUP_FILE=$(ls -1 "$BACKUP_DIR" | grep "vzdump" | sed -n "${FILE_NUM}p")

    if [ -z "$BACKUP_FILE" ]; then
        echo "❌ Invalid selection. Exiting."
        exit 1
    fi

    echo "🔄 Restoring from backup: $BACKUP_FILE..."
    BACKUP_PATH="$BACKUP_DIR/$BACKUP_FILE"

    # Extract VM/Container ID and type (Fixed)
    VM_CT_ID=$(echo "$BACKUP_FILE" | sed -E 's/.*vzdump-(lxc|qemu)-([0-9]+)-.*/\2/' | tr -d '[:space:]')
    TYPE=$(echo "$BACKUP_FILE" | sed -E 's/.*vzdump-(lxc|qemu)-.*/\1/' | tr -d '[:space:]')

    if [ -z "$VM_CT_ID" ] || [ -z "$TYPE" ]; then
        echo "❌ Could not determine VM/Container ID or type from the backup file. Exiting."
        exit 1
    fi

    # Restore based on type (VM or Container)
    if [ "$TYPE" == "qemu" ]; then
        echo "⚙️ Restoring VM $VM_CT_ID..."
        qmrestore "$BACKUP_PATH" "$VM_CT_ID" --force
    elif [ "$TYPE" == "lxc" ]; then
        echo "⚙️ Restoring Container $VM_CT_ID to local-lvm storage..."
        pct restore "$VM_CT_ID" "$BACKUP_PATH" --storage local-lvm --force
    else
        echo "❌ Unknown backup type. Exiting."
        exit 1
    fi

    echo "✅ Restoration completed successfully!"
}



# Menu for user selection
echo "==============================="
echo "   Proxmox Backup & Restore   "
echo "==============================="
echo "Choose an option:"
echo "1) Backup all VMs and Containers"
echo "2) Restore a VM or Container from a backup"
read -r CHOICE

case $CHOICE in
    1)
        backup_vms_containers
        ;;
    2)
        restore_vms_containers
        ;;
    *)
        echo "❌ Invalid choice. Exiting."
        exit 1
        ;;
esac
