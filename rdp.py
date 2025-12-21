#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "Devi eseguire come root"
  exit 1
fi

echo "[+] Aggiornamento sistema"
apt update -y

echo "[+] Installazione XFCE + XRDP"
DEBIAN_FRONTEND=noninteractive apt install -y \
  xfce4 xfce4-goodies \
  xrdp \
  lightdm

echo "[+] Abilito servizi"
systemctl enable xrdp
systemctl enable lightdm

echo "[+] Permessi XRDP"
adduser xrdp ssl-cert || true

echo "[+] Configuro XRDP startwm.sh"
cat > /etc/xrdp/startwm.sh <<'EOF'
#!/bin/sh
unset DBUS_SESSION_BUS_ADDRESS
unset XDG_RUNTIME_DIR
exec startxfce4 &
EOF

chmod +x /etc/xrdp/startwm.sh

echo "[+] Configuro XRDP ini"
sed -i 's/^crypt_level=.*/crypt_level=high/' /etc/xrdp/xrdp.ini
sed -i 's/^security_layer=.*/security_layer=negotiate/' /etc/xrdp/xrdp.ini

echo "[+] Configuro sessione XFCE per utenti"
for d in /home/*; do
  if [ -d "$d" ]; then
    USERNAME=$(basename "$d")
    echo "xfce4-session" > "$d/.xsession"
    chown "$USERNAME:$USERNAME" "$d/.xsession"
    chmod 644 "$d/.xsession"
  fi
done

echo "[+] Riavvio servizi"
systemctl restart xrdp
systemctl restart lightdm

echo
echo "[✓] COMPLETATO"
echo "    Desktop XFCE + XRDP pronti"
echo "    Collegati via RDP sulla porta 3389"
