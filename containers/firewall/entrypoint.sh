#!/bin/bash
# Script d'entrée pour le conteneur firewall

set -e

echo "Démarrage du conteneur firewall..."

# Créer les répertoires nécessaires pour rsyslog
mkdir -p /var/lib/rsyslog
chmod 755 /var/lib/rsyslog

# Créer les fichiers de logs UFW s'ils n'existent pas
touch /var/log/ufw.log /var/log/kern.log /var/log/messages
chmod 644 /var/log/ufw.log /var/log/kern.log /var/log/messages

# Démarrer rsyslog en arrière-plan
echo "Démarrage de rsyslog..."
rsyslogd

# Attendre que rsyslog soit prêt
sleep 2

# Tester l'envoi d'un log de test
logger "Firewall démarré - rsyslog opérationnel"

# Attendre que rsyslog soit prêt
sleep 2

# Configurer UFW
echo "Configuration de UFW..."
/usr/local/bin/setup-ufw.sh

# Garder le conteneur actif et afficher les logs
echo "Conteneur firewall opérationnel. Logs UFW:"
tail -f /var/log/ufw.log /var/log/syslog 2>/dev/null || sleep infinity



