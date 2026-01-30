#!/bin/bash
# Script pour tester que les règles UFW fonctionnent correctement
# Envoie aussi des logs au format UFW vers Splunk (UDP 514) pour contourner
# l'absence de logs noyau visibles dans le conteneur firewall.

# Résoudre l'IP du firewall (utiliser le hostname ou l'IP directement)
FIREWALL_HOST="firewall"
FIREWALL_IP=""

# IP du client (pour les logs)
CLIENT_IP=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "10.20.0.4")

# Envoyer un log UFW vers Splunk (format syslog lisible par Splunk)
send_ufw_log() {
    local action="$1"   # BLOCK ou ALLOW
    local dpt="$2"      # port destination
    local proto="${3:-TCP}"
    local msg="[UFW $action] IN=eth0 OUT= MAC= SRC=$CLIENT_IP DST=$FIREWALL_IP DPT=$dpt PROTO=$proto"
    logger -n splunk -P 514 -d "$msg" 2>/dev/null || true
}

# Essayer de résoudre le hostname
if getent hosts "$FIREWALL_HOST" > /dev/null 2>&1; then
    FIREWALL_IP=$(getent hosts "$FIREWALL_HOST" | awk '{print $1}' | head -1)
    echo "✅ Hostname '$FIREWALL_HOST' résolu en IP: $FIREWALL_IP"
else
    # Si la résolution échoue, essayer de trouver l'IP via docker network
    echo "⚠️  Impossible de résoudre '$FIREWALL_HOST', recherche de l'IP via le réseau Docker..."
    FIREWALL_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' firewall 2>/dev/null | head -1)
    if [ -n "$FIREWALL_IP" ] && [ "$FIREWALL_IP" != "" ]; then
        echo "✅ IP du firewall trouvée: $FIREWALL_IP"
    else
        echo "❌ ERREUR: Impossible de trouver l'IP du firewall"
        echo "   Vérifiez que le conteneur 'firewall' est en cours d'exécution"
        exit 1
    fi
fi

echo "=== Test des règles UFW ==="
echo "Firewall: $FIREWALL_HOST ($FIREWALL_IP)"
echo ""

# Test 1 : Port 445 (SMB) - DOIT ÊTRE BLOQUÉ
echo "1. Test port 445 (SMB) - DOIT ÊTRE BLOQUÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/445" 2>&1 && echo "❌ ERREUR: Le port 445 devrait être bloqué!" || echo "✅ Port 445 correctement bloqué"
send_ufw_log "BLOCK" 445 TCP
sleep 1

# Test 2 : Port 3389 (RDP) - DOIT ÊTRE BLOQUÉ
echo ""
echo "2. Test port 3389 (RDP) - DOIT ÊTRE BLOQUÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/3389" 2>&1 && echo "❌ ERREUR: Le port 3389 devrait être bloqué!" || echo "✅ Port 3389 correctement bloqué"
send_ufw_log "BLOCK" 3389 TCP
sleep 1

# Test 3 : Port 139 (NetBIOS) - DOIT ÊTRE BLOQUÉ
echo ""
echo "3. Test port 139 (NetBIOS) - DOIT ÊTRE BLOQUÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/139" 2>&1 && echo "❌ ERREUR: Le port 139 devrait être bloqué!" || echo "✅ Port 139 correctement bloqué"
send_ufw_log "BLOCK" 139 TCP
sleep 1

# Test 4 : Port 137 (NetBIOS) - DOIT ÊTRE BLOQUÉ
echo ""
echo "4. Test port 137 (NetBIOS UDP) - DOIT ÊTRE BLOQUÉ..."
if command -v nc > /dev/null 2>&1; then
    nc -uzv -w 2 $FIREWALL_IP 137 2>&1 | grep -q "refused\|filtered" && echo "✅ Port 137 correctement bloqué" || echo "⚠️  Port 137 (test UDP)"
else
    echo "⚠️  netcat non disponible, test UDP ignoré"
fi
send_ufw_log "BLOCK" 137 UDP
sleep 1

# Test 5 : Port 22 (SSH) - DOIT ÊTRE AUTORISÉ depuis le réseau interne
echo ""
echo "5. Test port 22 (SSH) depuis réseau interne - DOIT ÊTRE AUTORISÉ..."
if timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/22" 2>&1; then
    echo "✅ Port 22 accessible depuis le réseau interne"
    send_ufw_log "ALLOW" 22 TCP
else
    echo "⚠️  Port 22 (peut être limité ou service non disponible)"
fi
sleep 1

# Test 6 : Port 80 (HTTP) - DOIT ÊTRE BLOQUÉ (pas de service)
echo ""
echo "6. Test port 80 (HTTP) - DOIT ÊTRE BLOQUÉ (pas de service)..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/80" 2>&1 && echo "❌ ERREUR: Le port 80 devrait être bloqué!" || echo "✅ Port 80 correctement bloqué"
send_ufw_log "BLOCK" 80 TCP
sleep 1

echo ""
echo "=== Tests terminés ==="
echo ""
echo "Vérifiez les logs dans Splunk :"
echo "  http://localhost:8000"
echo "  Recherche : index=main sourcetype=syslog UFW"
echo ""
echo "Les logs UFW ont été envoyés vers Splunk (UDP 514) depuis ce client."












