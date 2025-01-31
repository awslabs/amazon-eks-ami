#!/bin/bash
set -ex

SCRIPT_DIR="$HOME/bb"
mkdir -p "$SCRIPT_DIR"

SCRIPT_PATH="$SCRIPT_DIR/devmapper_reload.sh"

cat > "$SCRIPT_PATH" << 'EOL'
#!/bin/bash
set -ex

DATA_DIR=/var/lib/containerd/io.containerd.snapshotter.v1.devmapper
POOL_NAME=devpool

# Allocate loop devices
DATA_DEV=$(sudo losetup --find --show "${DATA_DIR}/data")
META_DEV=$(sudo losetup --find --show "${DATA_DIR}/meta")

# Define thin-pool parameters.
# See https://www.kernel.org/doc/Documentation/device-mapper/thin-provisioning.txt for details.
SECTOR_SIZE=512
DATA_SIZE="$(sudo blockdev --getsize64 -q ${DATA_DEV})"
LENGTH_IN_SECTORS=$(bc <<< "${DATA_SIZE}/${SECTOR_SIZE}")
DATA_BLOCK_SIZE=128
LOW_WATER_MARK=32768

# Create a thin-pool device
sudo dmsetup create "${POOL_NAME}" \
    --table "0 ${LENGTH_IN_SECTORS} thin-pool ${META_DEV} ${DATA_DEV} ${DATA_BLOCK_SIZE} ${LOW_WATER_MARK}"
EOL

chmod +x "$SCRIPT_PATH"

SERVICE_PATH="/lib/systemd/system/devmapper_reload.service"

# Create the systemd service file
sudo tee "$SERVICE_PATH" > /dev/null << EOL
[Unit]
Description=Devmapper reload script

[Service]
ExecStart=$SCRIPT_PATH

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable devmapper_reload.service
sudo systemctl start devmapper_reload.service
