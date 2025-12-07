#!/bin/bash
# Script pour vérifier pourquoi les logs UFW ne sont pas générés

echo "=== Diagnostic UFW ==="

# 1. Vérifier que UFW est actif
echo "1. Statut UFW:"
ufw status verbose | head -10

# 2. Vérifier le niveau de logging
echo ""
echo "2. Niveau de logging:"
ufw status verbose | grep -i logging

# 3. Vérifier les règles
echo ""
echo "3. Règles UFW:"
ufw status numbered | head -20

# 4. Vérifier les logs kernel actuels
echo ""
echo "4. Derniers logs kernel (20 dernières lignes):"
tail -20 /var/log/kern.log

# 5. Chercher spécifiquement les logs UFW
echo ""
echo "5. Logs UFW dans kern.log:"
grep -i "UFW" /var/log/kern.log | tail -10 || echo "AUCUN LOG UFW TROUVÉ!"

# 6. Vérifier que rsyslog fonctionne
echo ""
echo "6. Processus rsyslog:"
ps aux | grep rsyslog | grep -v grep || echo "rsyslog n'est pas en cours d'exécution"

# 7. Tester l'envoi d'un log
echo ""
echo "7. Test d'envoi de log vers logcollector:"
logger -n logcollector -P 514 -d "TEST UFW - $(date)"

# 8. Vérifier la configuration rsyslog
echo ""
echo "8. Configuration rsyslog:"
cat /etc/rsyslog.conf | grep -v "^#" | grep -v "^$" | head -20

echo ""
echo "=== Diagnostic terminé ==="
echo ""
echo "Pour générer des logs UFW, testez:"
echo "  # Depuis un autre conteneur"
echo "  nc -zv firewall 445"
echo "  timeout 2 bash -c '</dev/tcp/firewall/445' 2>&1 || true"
echo ""
echo "Puis vérifiez immédiatement:"
echo "  tail -f /var/log/kern.log | grep UFW"

