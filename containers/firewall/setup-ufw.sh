#!/bin/bash
# Script de configuration UFW avec les règles spécifiées

set -e

# Variables
INTERNAL_NETWORK="${INTERNAL_NETWORK:-10.20.0.0/16}"
LOGGING_LEVEL="${LOGGING_LEVEL:-high}"

echo "Configuration UFW..."

# Réinitialiser UFW
ufw --force reset

# Règles par défaut
echo "Application des règles par défaut..."
ufw default deny incoming
ufw default allow outgoing
ufw default deny routed

# Configuration du logging
echo "Configuration du logging niveau $LOGGING_LEVEL..."
ufw logging $LOGGING_LEVEL

# Vérifier que le logging est bien activé
echo "Vérification du niveau de logging..."
ufw status verbose | grep -i logging || echo "ATTENTION: Le logging UFW n'est pas activé!"

# Services internes autorisés
echo "Configuration des services internes..."
# SSH interne depuis le réseau interne
ufw allow from $INTERNAL_NETWORK to any port 22 proto tcp comment 'SSH interne'
# Envoi des logs vers Splunk
ufw allow out 514/udp comment 'Envoi logs vers Splunk'

# Trafic utile autorisé
echo "Configuration du trafic sortant autorisé..."
# DNS sortant
ufw allow out 53/udp comment 'DNS sortant'
ufw allow out 53/tcp comment 'DNS sortant TCP'
# Web sortant
ufw allow out 80/tcp comment 'HTTP sortant'
ufw allow out 443/tcp comment 'HTTPS sortant'

# Blocage des services sensibles
echo "Blocage des services sensibles..."
# SMB/NetBIOS
ufw deny 137/udp comment 'Blocage NetBIOS Name Service'
ufw deny 138/udp comment 'Blocage NetBIOS Datagram Service'
ufw deny 139/tcp comment 'Blocage NetBIOS Session Service'
ufw deny 445/tcp comment 'Blocage SMB'
# RDP
ufw deny 3389/tcp comment 'Blocage RDP'

# Sécurité supplémentaire
echo "Configuration de la sécurité supplémentaire..."
# Limitation SSH pour réduire brute-force
ufw limit 22/tcp comment 'Limitation SSH anti brute-force'

# Activation de UFW
echo "Activation de UFW..."
ufw --force enable

# Vérifier que le logging est bien activé
echo "Vérification du logging..."
LOGGING_STATUS=$(ufw status verbose | grep -i logging | head -1)
echo "Logging status: $LOGGING_STATUS"

if ! echo "$LOGGING_STATUS" | grep -qi "on (high)"; then
    echo "ATTENTION: Le logging n'est pas activé correctement!"
    echo "Réactivation du logging..."
    ufw logging high
fi

# Affichage du statut
echo ""
echo "Statut UFW:"
ufw status verbose

# Vérifier que les logs sont bien générés
echo ""
echo "Vérification des logs UFW..."
if [ -f /var/log/kern.log ]; then
    UFW_LOGS=$(grep -i "UFW" /var/log/kern.log | tail -3)
    if [ -z "$UFW_LOGS" ]; then
        echo "Aucun log UFW trouvé dans /var/log/kern.log (normal si aucun trafic n'a été généré)"
    else
        echo "Derniers logs UFW:"
        echo "$UFW_LOGS"
    fi
else
    echo "Le fichier /var/log/kern.log n'existe pas encore"
fi

echo ""
echo "Configuration UFW terminée avec succès!"





