import os
import socket
import subprocess

# Funzione per ottenere l'IP locale
def get_local_ip():
    local_ip = socket.gethostbyname(socket.gethostname())
    return local_ip

# Funzione per attivare e configurare il servizio SSH sulla macchina locale
def setup_ssh():
    # Verifica se SSH è già installato
    print("Verificando se il pacchetto OpenSSH è installato...")
    result = subprocess.run(['dpkg', '-l', 'openssh-server'], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode != 0:
        print("Installazione di OpenSSH Server in corso...")
        subprocess.run(['sudo', 'apt-get', 'install', '-y', 'openssh-server'])
    else:
        print("OpenSSH Server è già installato.")

    # Verifica se il servizio SSH è attivo
    print("Verificando se il servizio SSH è attivo...")
    result = subprocess.run(['systemctl', 'is-active', '--quiet', 'ssh'])
    if result.returncode != 0:
        print("Il servizio SSH non è attivo. Avvio del servizio SSH...")
        subprocess.run(['sudo', 'systemctl', 'start', 'ssh'])
        subprocess.run(['sudo', 'systemctl', 'enable', 'ssh'])
        print("Servizio SSH avviato e abilitato al boot.")
    else:
        print("Il servizio SSH è già attivo.")

    # Configura il firewall per permettere le connessioni SSH (porta 22)
    print("Configurando il firewall per consentire SSH sulla porta 22...")
    subprocess.run(['sudo', 'ufw', 'allow', '22/tcp'], check=True)
    subprocess.run(['sudo', 'ufw', 'enable'], check=True)
    print("Firewall configurato per consentire SSH.")

# Funzione principale
def main():
    # Imposta il servizio SSH e configura la macchina locale
    setup_ssh()
    
    # Ottieni l'IP locale della macchina
    local_ip = get_local_ip()

    # Mostra le informazioni per collegarsi tramite SSH da remoto
    print("\nConfigurazione completata.")
    print(f"Per collegarti a questa macchina tramite SSH da remoto, usa il comando:")
    print(f"ssh kali557@{local_ip} -p 22")
    print("\nRicorda: La password per SSH è 'kali557'. Non è necessario specificarla nel comando.")

if __name__ == "__main__":
    main()
