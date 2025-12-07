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

# Tester l'envoi d'un log de test vers le logcollector
logger -n logcollector -P 514 -d "Firewall démarré - rsyslog opérationnel"

# Attendre que rsyslog soit prêt
sleep 2

# Configurer UFW
echo "Configuration de UFW..."
/usr/local/bin/setup-ufw.sh

# Vérifier que les logs sont bien générés
echo "Vérification des logs UFW..."
tail -5 /var/log/kern.log | grep -i ufw || echo "Aucun log UFW pour le moment"

# Garder le conteneur actif
echo "Conteneur firewall opérationnel."
echo "Pour voir les logs en temps réel: docker exec firewall tail -f /var/log/kern.log | grep UFW"
sleep infinity



