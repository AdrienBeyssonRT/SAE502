#!/bin/bash
# Diagnostic de la chaîne de logs : firewall → Splunk (direct, sans logcollector)
# À lancer depuis la racine du projet sur la VM
# Option : ./diagnostic-logs.sh --generate-traffic  (génère du trafic avant les vérifications)

GENERATE_TRAFFIC=false
[[ "${1:-}" == "--generate-traffic" || "${1:-}" == "-g" ]] && GENERATE_TRAFFIC=true

echo "=========================================="
echo "  DIAGNOSTIC CHAÎNE DE LOGS UFW"
echo "  (firewall → Splunk)"
echo "=========================================="
echo ""

if "$GENERATE_TRAFFIC"; then
  echo "0. Test envoi direct client → Splunk (1 message UFW)..."
  echo "----------------------------------------"
  docker exec client logger -n splunk -P 514 -d "[UFW BLOCK] DIAGNOSTIC SRC=10.20.0.4 DST=10.20.0.2 DPT=999 PROTO=TCP" 2>/dev/null && echo "   Message envoyé (client → splunk:514)" || echo "   Échec envoi (vérifier client + réseau)"
  echo "0b. Génération de trafic UFW (test-rules-ufw.sh)..."
  docker exec client /usr/local/bin/test-rules-ufw.sh 2>/dev/null || true
  echo "   Attente 15 s pour propagation des logs..."
  sleep 15
  echo ""
fi

echo "1a. IP / interfaces / règles UFW (le trafic atteint-il le firewall ?)"
echo "----------------------------------------"
echo "   IP du firewall (depuis client) :"
docker exec client getent hosts firewall 2>/dev/null | awk '{print "     " $2 " -> " $1}' || echo "     (résolution échouée)"
echo "   Interfaces et IP dans le firewall :"
docker exec firewall ip -4 addr show 2>/dev/null | grep -E 'inet |^[0-9]:' | sed 's/^/     /' || docker exec firewall hostname -I 2>/dev/null | sed 's/^/     /'
echo "   Compteurs iptables INPUT (pkts) — doivent augmenter après test-rules-ufw.sh :"
docker exec firewall iptables -L INPUT -v -n 2>/dev/null | head -20 | sed 's/^/     /'
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
  # Essayer aussi BLOCK/iptables (format netfilter)
  if dmesg 2>/dev/null | grep -iE 'BLOCK|iptables|nf_log' | tail -5; then
    : # des logs type firewall trouvés
  else
    echo "   Aucun log UFW dans dmesg"
    echo "   Derniers messages noyau :"
    dmesg 2>/dev/null | tail -6 | sed 's/^/   /'
    echo "   → Générer du trafic puis relancer : ./diagnostic-logs.sh --generate-traffic"
  fi
fi
echo ""

echo "1c. Rsyslog sur l'HÔTE (config Splunk + service)"
echo "----------------------------------------"
if [ -f /etc/rsyslog.d/99-splunk-ufw.conf ]; then
  echo "   Config OK : /etc/rsyslog.d/99-splunk-ufw.conf"
  grep -v '^#' /etc/rsyslog.d/99-splunk-ufw.conf | grep -v '^$' | sed 's/^/   /'
else
  echo "   Config absente : sudo cp ansible/files/99-splunk-ufw.conf /etc/rsyslog.d/ && sudo systemctl restart rsyslog"
fi
systemctl is-active rsyslog &>/dev/null && echo "   Service rsyslog : actif" || echo "   Service rsyslog : inactif ou absent"
echo ""

echo "1d. Fichier kern.log sur l'HÔTE (/var/log/kern.log)"
echo "----------------------------------------"
if [ -r /var/log/kern.log ]; then
  if grep -i ufw /var/log/kern.log 2>/dev/null | tail -5; then
    : # des logs UFW trouvés
  else
    echo "   Aucun log UFW dans /var/log/kern.log de l'hôte"
    echo "   Dernières lignes du fichier :"
    tail -5 /var/log/kern.log 2>/dev/null | sed 's/^/   /'
  fi
else
  echo "   Fichier /var/log/kern.log absent ou illisible"
fi
echo ""

echo "2. Rsyslog tourne dans le firewall ?"
echo "----------------------------------------"
docker exec firewall ps aux 2>/dev/null | grep -E "rsyslog|PID" || echo "   Rsyslog non trouvé ou conteneur firewall absent"
echo ""

echo "3. Le firewall peut joindre Splunk ?"
echo "----------------------------------------"
if docker exec firewall ping -c 1 splunk 2>/dev/null; then
  echo "   OK (réseau main_network opérationnel)"
else
  echo "   ÉCHEC (vérifier que firewall et splunk sont sur main_network)"
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
echo "• Si 1a : compteurs iptables à 0 après --generate-traffic → trafic n'atteint pas le firewall (IP/réseau). Sinon trafic OK, problème = visibilité logs noyau."
echo "• Si 1/1b/1d vides : lancer : ./diagnostic-logs.sh --generate-traffic  (génère du trafic puis revérifie)"
echo "• Si 1c manquant : sudo cp ansible/files/99-splunk-ufw.conf /etc/rsyslog.d/ && sudo systemctl restart rsyslog"
echo "• Si 1b et 1d vides : logs noyau du conteneur non visibles sur l'hôte (limitation noyau/Docker) ; seuls les vrais logs UFW apparaîtront dans Splunk si visibles"
echo "• Si 2 échoue   : redémarrer le firewall : docker compose restart firewall"
echo "• Si 3 échoue   : vérifier docker compose (firewall + splunk sur main_network)"
echo "• Si 4 est vide : reconstruire l'image Splunk : docker compose build splunk && docker compose up -d splunk"
echo "• Si 5 est vide : lancer avec génération de trafic : ./diagnostic-logs.sh --generate-traffic"
echo "  Les logs viennent du CLIENT (test-rules-ufw.sh → logger → Splunk), pas du noyau firewall."
echo ""
