#!/bin/bash
# Script de test pour vérifier le système de logs

echo "=== Test du système de logs ==="
echo ""

echo "1. Vérification des logs dans le firewall..."
docker exec firewall ls -la /var/log/ | grep -E "(ufw|kern)"

echo ""
echo "2. Vérification que rsyslog fonctionne dans le firewall..."
docker exec firewall ps aux | grep rsyslog

echo ""
echo "3. Vérification de la connectivité firewall -> logcollector..."
docker exec firewall ping -c 2 logcollector

echo ""
echo "4. Vérification que le logcollector écoute sur le port 514..."
docker exec logcollector netstat -ulnp 2>/dev/null | grep 514 || echo "netstat non disponible, test avec ss..."
docker exec logcollector ss -ulnp 2>/dev/null | grep 514 || echo "ss non disponible"

echo ""
echo "5. Vérification des fichiers de logs dans le logcollector..."
docker exec logcollector ls -la /var/log/firewall/ 2>/dev/null || echo "Répertoire /var/log/firewall/ n'existe pas ou est vide"

echo ""
echo "6. Test d'envoi manuel d'un log..."
docker exec firewall logger -n logcollector -P 514 -d "TEST LOG depuis firewall"

echo ""
echo "7. Vérification des logs kernel dans le firewall..."
docker exec firewall tail -5 /var/log/kern.log 2>/dev/null || echo "Aucun log dans /var/log/kern.log"

echo ""
echo "8. Vérification des logs UFW dans le firewall..."
docker exec firewall tail -5 /var/log/ufw.log 2>/dev/null || echo "Aucun log dans /var/log/ufw.log"

echo ""
echo "=== Test terminé ==="
echo ""
echo "Pour générer des logs UFW, exécutez depuis le client:"
echo "  docker exec -it client bash"
echo "  nmap -p 445 firewall"
echo "  nc -zv firewall 445"

