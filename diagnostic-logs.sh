#!/bin/bash
# Diagnostic de la chaîne de logs : firewall → Splunk (direct, sans logcollector)
# À lancer depuis la racine du projet sur la VM

echo "=========================================="
echo "  DIAGNOSTIC CHAÎNE DE LOGS UFW"
echo "  (firewall → Splunk)"
echo "=========================================="
echo ""

echo "1. Logs UFW dans le FIREWALL (kern.log)"
echo "----------------------------------------"
if docker exec firewall tail -20 /var/log/kern.log 2>/dev/null | grep -i ufw; then
  : # des logs UFW sont présents
else
  echo "   Aucun log UFW dans kern.log du conteneur"
fi
echo ""

echo "1b. Logs noyau sur l'HÔTE (dmesg) — source réelle des logs UFW"
echo "----------------------------------------"
if dmesg 2>/dev/null | grep -i ufw | tail -10; then
  : # des logs UFW sont présents sur l'hôte
else
  echo "   Aucun log UFW dans dmesg (générer du trafic : test-rules-ufw.sh)"
fi
echo ""

echo "2. Rsyslog tourne dans le firewall ?"
echo "----------------------------------------"
docker exec firewall ps aux 2>/dev/null | grep -E "rsyslog|PID" || echo "   Rsyslog non trouvé ou conteneur firewall absent"
echo ""

echo "3. Le firewall peut joindre Splunk ?"
echo "----------------------------------------"
if docker exec firewall ping -c 1 splunk 2>/dev/null; then
  echo "   OK (réseau logs_network opérationnel)"
else
  echo "   ÉCHEC (vérifier que firewall et splunk sont sur logs_network)"
fi
echo ""

echo "4. Config Splunk : entrée UDP 514"
echo "----------------------------------------"
if docker exec splunk cat /opt/splunk/etc/system/local/inputs.conf 2>/dev/null | grep -A6 "udp://514"; then
  : # config affichée
else
  # Fallback : config par défaut dans l'image (etc/system/default/inputs.conf)
  docker exec splunk cat /opt/splunk/etc/system/default/inputs.conf 2>/dev/null | grep -A6 "udp://514" || echo "   Entrée [udp://514] non trouvée (reconstruire l'image splunk)"
fi
echo ""

echo "5. Logs UFW reçus par Splunk (recherche index)"
echo "----------------------------------------"
if docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog UFW' -auth admin:splunk1RT3 2>/dev/null | head -15; then
  : # résultats affichés
else
  echo "   Aucun résultat ou Splunk non prêt (attendre 1–2 min après démarrage)"
fi
echo ""

echo "=========================================="
echo "  RÉSUMÉ"
echo "=========================================="
echo "• Si 1/1b vides : générer du trafic : docker exec client /usr/local/bin/test-rules-ufw.sh"
echo "• Si 1b OK mais 5 vide : l'hôte envoie vers Splunk (rsyslog) — relancer deploy ou : sudo cp ansible/files/99-splunk-ufw.conf /etc/rsyslog.d/ && sudo systemctl restart rsyslog"
echo "• Si 2 échoue   : redémarrer le firewall : docker compose restart firewall"
echo "• Si 3 échoue   : vérifier docker compose (firewall + splunk sur logs_network)"
echo "• Si 4 est vide : reconstruire l'image Splunk : docker compose build splunk && docker compose up -d splunk"
echo "• Si 5 est vide : après avoir fait 1, attendre 30 s puis relancer ce diagnostic"
echo ""
