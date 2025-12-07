#!/bin/bash
# Script pour forcer la génération de logs UFW

echo "=== Test de génération de logs UFW ==="

# Vérifier que UFW est actif
echo "1. Vérification UFW..."
ufw status | head -5

# Vérifier le niveau de logging
echo ""
echo "2. Niveau de logging UFW:"
ufw status verbose | grep Logging

# Générer du trafic depuis l'extérieur du réseau interne
echo ""
echo "3. Vérification des logs kernel..."
tail -5 /var/log/kern.log | grep -i ufw || echo "Aucun log UFW dans kern.log"

# Tester l'envoi d'un log
echo ""
echo "4. Test d'envoi de log..."
logger "TEST LOG depuis firewall - $(date)"

# Vérifier que rsyslog fonctionne
echo ""
echo "5. Vérification rsyslog..."
ps aux | grep rsyslog | grep -v grep

echo ""
echo "=== Test terminé ==="
echo ""
echo "Pour générer des logs UFW, depuis le client:"
echo "  docker exec -it client bash"
echo "  nmap -p 445 firewall"
echo "  nc -zv firewall 445"


