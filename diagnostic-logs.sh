#!/bin/bash
# Diagnostic de la chaîne de logs : firewall → logcollector → Splunk
# À lancer depuis la racine du projet sur la VM

set -e

echo "=========================================="
echo "  DIAGNOSTIC CHAÎNE DE LOGS UFW"
echo "=========================================="
echo ""

echo "1. Logs UFW dans le FIREWALL (kern.log)"
echo "----------------------------------------"
docker exec firewall tail -20 /var/log/kern.log 2>/dev/null | grep -i ufw || echo "   Aucun log UFW dans kern.log"
echo ""

echo "2. Rsyslog tourne dans le firewall ?"
echo "----------------------------------------"
docker exec firewall ps aux 2>/dev/null | grep -E "rsyslog|PID" || true
echo ""

echo "3. Logs reçus par le LOGCOLLECTOR"
echo "----------------------------------------"
docker exec logcollector sh -c "tail -30 /var/log/firewall/*.log 2>/dev/null | grep -i ufw" || echo "   Aucun log UFW dans le logcollector"
echo ""

echo "4. Rsyslog tourne dans le logcollector ?"
echo "----------------------------------------"
docker exec logcollector ps aux 2>/dev/null | grep -E "rsyslog|PID" || true
echo ""

echo "5. Le logcollector peut joindre Splunk ?"
echo "----------------------------------------"
docker exec logcollector ping -c 1 splunk 2>/dev/null && echo "   OK" || echo "   ÉCHEC"
echo ""

echo "6. Config Splunk : entrée UDP 514"
echo "----------------------------------------"
docker exec splunk cat /opt/splunk/etc/system/local/inputs.conf 2>/dev/null | grep -A5 "udp://514" || echo "   Fichier inputs.conf non trouvé ou pas de [udp://514]"
echo ""

echo "=========================================="
echo "  RÉSUMÉ"
echo "=========================================="
echo "Si 1 est vide : lancer d’abord : docker exec client /usr/local/bin/test-rules-ufw.sh"
echo "Si 3 est vide : le firewall n’envoie pas au logcollector (vérifier rsyslog firewall + réseau)."
echo "Si 5 échoue : problème réseau Docker entre logcollector et splunk."
echo "Si 6 est vide : reconstruire l’image splunk ou lancer : ./containers/splunk/deploy-splunk-config.sh"
echo ""
