#!/bin/bash
# Script pour tester que les règles UFW fonctionnent correctement

# Résoudre l'IP du firewall (utiliser le hostname ou l'IP directement)
FIREWALL_HOST="firewall"
FIREWALL_IP=""

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
sleep 1

# Test 2 : Port 3389 (RDP) - DOIT ÊTRE BLOQUÉ
echo ""
echo "2. Test port 3389 (RDP) - DOIT ÊTRE BLOQUÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/3389" 2>&1 && echo "❌ ERREUR: Le port 3389 devrait être bloqué!" || echo "✅ Port 3389 correctement bloqué"
sleep 1

# Test 3 : Port 139 (NetBIOS) - DOIT ÊTRE BLOQUÉ
echo ""
echo "3. Test port 139 (NetBIOS) - DOIT ÊTRE BLOQUÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/139" 2>&1 && echo "❌ ERREUR: Le port 139 devrait être bloqué!" || echo "✅ Port 139 correctement bloqué"
sleep 1

# Test 4 : Port 137 (NetBIOS) - DOIT ÊTRE BLOQUÉ
echo ""
echo "4. Test port 137 (NetBIOS UDP) - DOIT ÊTRE BLOQUÉ..."
if command -v nc > /dev/null 2>&1; then
    nc -uzv -w 2 $FIREWALL_IP 137 2>&1 | grep -q "refused\|filtered" && echo "✅ Port 137 correctement bloqué" || echo "⚠️  Port 137 (test UDP)"
else
    echo "⚠️  netcat non disponible, test UDP ignoré"
fi
sleep 1

# Test 5 : Port 22 (SSH) - DOIT ÊTRE AUTORISÉ depuis le réseau interne
echo ""
echo "5. Test port 22 (SSH) depuis réseau interne - DOIT ÊTRE AUTORISÉ..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/22" 2>&1 && echo "✅ Port 22 accessible depuis le réseau interne" || echo "⚠️  Port 22 (peut être limité ou service non disponible)"
sleep 1

# Test 6 : Port 80 (HTTP) - DOIT ÊTRE BLOQUÉ (pas de service)
echo ""
echo "6. Test port 80 (HTTP) - DOIT ÊTRE BLOQUÉ (pas de service)..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/80" 2>&1 && echo "❌ ERREUR: Le port 80 devrait être bloqué!" || echo "✅ Port 80 correctement bloqué"
sleep 1

echo ""
echo "=== Tests terminés ==="
echo ""
echo "Vérifiez maintenant les logs dans l'interface web:"
echo "  http://localhost:5000"
echo ""
echo "Vous devriez voir des logs BLOCK pour les ports 445, 3389, 139, 137, 80"












