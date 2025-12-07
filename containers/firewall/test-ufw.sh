#!/bin/bash
# Script pour tester et forcer la génération de logs UFW

echo "=== Test de génération de logs UFW ==="

# Vérifier que UFW est actif
echo "1. Vérification UFW..."
ufw status | head -5

# Vérifier le niveau de logging
echo ""
echo "2. Niveau de logging UFW:"
ufw status verbose | grep Logging

# Vérifier les logs kernel actuels
echo ""
echo "3. Derniers logs kernel (5 dernières lignes):"
tail -5 /var/log/kern.log

# Vérifier que rsyslog fonctionne
echo ""
echo "4. Vérification rsyslog..."
ps aux | grep rsyslog | grep -v grep || echo "rsyslog n'est pas en cours d'exécution"

# Tester l'envoi d'un log manuel
echo ""
echo "5. Test d'envoi de log manuel vers logcollector..."
logger -n logcollector -P 514 -d "TEST LOG depuis firewall - $(date)"

echo ""
echo "=== Test terminé ==="
echo ""
echo "Pour générer des logs UFW, depuis le client ou attacker:"
echo "  # Créer de vraies connexions TCP (pas juste des scans)"
echo "  timeout 2 bash -c '</dev/tcp/firewall/445' 2>&1 || true"
echo "  timeout 2 bash -c '</dev/tcp/firewall/3389' 2>&1 || true"
echo "  nc -zv -w 2 firewall 445"
echo "  nc -zv -w 2 firewall 3389"
echo ""
echo "Puis vérifier les logs:"
echo "  docker exec firewall tail -20 /var/log/kern.log | grep -i ufw"

