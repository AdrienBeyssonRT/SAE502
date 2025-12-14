#!/bin/bash
# Script d'entrée pour le conteneur logcollector

set -euo pipefail

echo "Démarrage du collecteur de logs..."

# Créer les répertoires nécessaires s'ils n'existent pas
mkdir -p /var/lib/rsyslog
mkdir -p /var/log/firewall
chmod 755 /var/lib/rsyslog
chmod 755 /var/log/firewall

# Vérifier la configuration
echo "Vérification de la configuration rsyslog..."
if ! rsyslogd -N1 2>&1; then
    echo "⚠️  Erreur dans la configuration rsyslog, mais continuation..."
fi

# Attendre que Splunk soit prêt (optionnel, mais recommandé)
echo "Attente que Splunk soit prêt..."
for i in {1..30}; do
    if getent hosts splunk > /dev/null 2>&1; then
        echo "✅ Splunk détecté"
        break
    fi
    sleep 2
done

# Démarrer rsyslog en mode foreground
echo "Démarrage de rsyslog en mode serveur..."
echo "  - Réception UDP sur port 514"
echo "  - Envoi vers Splunk sur port 514 (UDP)"
echo "  - Stockage local dans /var/log/firewall/"
exec rsyslogd -n



