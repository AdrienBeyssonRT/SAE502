#!/bin/bash
# Script pour générer du trafic qui déclenchera des logs UFW

echo "=== Génération de trafic pour déclencher des logs UFW ==="

FIREWALL_IP="firewall"
# Ou utiliser l'IP directement si le DNS ne fonctionne pas
# FIREWALL_IP="172.20.0.3"

echo "1. Test de connexion TCP sur le port 445 (SMB - devrait être BLOQUÉ)..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/445" 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "2. Test de connexion TCP sur le port 3389 (RDP - devrait être BLOQUÉ)..."
timeout 2 bash -c "</dev/tcp/$FIREWALL_IP/3389" 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "3. Test avec netcat sur le port 445..."
nc -zv -w 2 $FIREWALL_IP 445 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "4. Test avec netcat sur le port 3389..."
nc -zv -w 2 $FIREWALL_IP 3389 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "5. Test avec netcat sur le port 80 (HTTP - devrait être BLOQUÉ car pas de service)..."
nc -zv -w 2 $FIREWALL_IP 80 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "6. Test avec netcat sur le port 443 (HTTPS - devrait être BLOQUÉ car pas de service)..."
nc -zv -w 2 $FIREWALL_IP 443 2>&1 || echo "Connexion refusée/bloquée (attendu)"

echo ""
echo "=== Tests terminés ==="
echo ""
echo "Attendez 3-5 secondes puis vérifiez les logs:"
echo "  docker exec firewall tail -20 /var/log/kern.log | grep -i ufw"
echo ""
echo "Ou vérifiez dans le logcollector:"
echo "  docker exec logcollector tail -20 /var/log/firewall/firewall_*.log | grep -i ufw"

