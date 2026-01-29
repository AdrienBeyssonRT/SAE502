#!/bin/bash
# Script d'entrée pour le conteneur firewall

set -euo pipefail

echo "Démarrage du conteneur firewall..."

# Créer les répertoires nécessaires pour rsyslog
mkdir -p /var/lib/rsyslog
chmod 755 /var/lib/rsyslog

# Créer les fichiers de logs UFW s'ils n'existent pas
touch /var/log/ufw.log /var/log/kern.log /var/log/messages
chmod 644 /var/log/ufw.log /var/log/kern.log /var/log/messages

# Vérifier la configuration rsyslog
echo "Vérification de la configuration rsyslog..."
if ! rsyslogd -N1 2>&1; then
    echo "⚠️  Erreur dans la configuration rsyslog, mais continuation..."
fi

# Démarrer rsyslog en mode foreground (pour qu'il reste actif)
echo "Démarrage de rsyslog en mode serveur..."
rsyslogd -n &
RSYSLOG_PID=$!

# Attendre que rsyslog soit prêt
sleep 3

# Vérifier que rsyslog fonctionne
if ! ps -p $RSYSLOG_PID > /dev/null 2>&1; then
    echo "❌ Erreur: rsyslog ne fonctionne pas"
    exit 1
fi
echo "✅ rsyslog démarré (PID: $RSYSLOG_PID)"

# Tester l'envoi d'un log de test vers Splunk (UDP 514)
echo "Test d'envoi de log vers Splunk..."
if logger -n splunk -P 514 -d "Firewall démarré - rsyslog opérationnel" 2>/dev/null; then
    echo "✅ Test d'envoi de log réussi"
else
    echo "⚠️  Impossible d'envoyer un log de test (normal si Splunk n'est pas encore prêt)"
fi

# Configurer UFW
echo "Configuration de UFW..."
if /usr/local/bin/setup-ufw.sh; then
    echo "✅ Configuration UFW terminée"
else
    echo "❌ Erreur lors de la configuration UFW"
    exit 1
fi

# Vérifier que UFW est actif
echo "Vérification du statut UFW..."
if ufw status | grep -q "Status: active"; then
    echo "✅ UFW est actif"
    ufw status verbose | head -5
else
    echo "❌ ERREUR: UFW n'est pas actif!"
    echo "Tentative de réactivation..."
    ufw --force enable || {
        echo "❌ Impossible d'activer UFW"
        exit 1
    }
fi

# Vérifier que le logging est activé
echo "Vérification du logging UFW..."
if ufw status verbose | grep -qi "logging.*on.*high"; then
    echo "✅ Logging UFW activé au niveau high"
else
    echo "⚠️  Logging UFW non activé, activation..."
    ufw logging high
fi

# Vérifier que les logs sont bien générés
echo "Vérification des logs UFW..."
sleep 2
if tail -10 /var/log/kern.log | grep -i ufw > /dev/null 2>&1; then
    echo "✅ Des logs UFW sont présents"
    tail -3 /var/log/kern.log | grep -i ufw || true
else
    echo "ℹ️  Aucun log UFW pour le moment (normal si aucun trafic n'a été généré)"
fi

# Vérifier que rsyslog peut envoyer des logs vers Splunk
echo "Test d'envoi de log vers Splunk..."
if logger -n splunk -P 514 -d "Firewall démarré - $(date)" 2>/dev/null; then
    echo "✅ Test d'envoi de log vers Splunk réussi"
else
    echo "⚠️  Impossible d'envoyer un log de test (normal si Splunk n'est pas encore prêt)"
fi

# Vérifier la connectivité avec Splunk
echo "Vérification de la connectivité avec Splunk..."
if ping -c 1 splunk > /dev/null 2>&1; then
    echo "✅ Connectivité avec Splunk OK"
else
    echo "⚠️  Impossible de joindre Splunk (vérifiez le réseau logs_network)"
fi

# Garder le conteneur actif et surveiller rsyslog
echo ""
echo "=========================================="
echo "Conteneur firewall opérationnel."
echo "=========================================="
echo "UFW Status: $(ufw status | head -1)"
echo "rsyslog PID: $RSYSLOG_PID"
echo ""
echo "Pour voir les logs UFW:"
echo "  docker exec firewall tail -f /var/log/kern.log | grep UFW"
echo ""

# Surveiller que rsyslog reste actif
while true; do
    if ! ps -p $RSYSLOG_PID > /dev/null 2>&1; then
        echo "❌ rsyslog s'est arrêté, redémarrage..."
        rsyslogd -n &
        RSYSLOG_PID=$!
        sleep 2
    fi
    sleep 10
done



