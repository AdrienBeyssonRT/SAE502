#!/bin/bash
# Test de connexion web

echo "Test HTTP vers firewall..."
curl -v http://firewall:80 --connect-timeout 5 || echo "Connexion bloquée (attendu)"

echo ""
echo "Test HTTPS vers firewall..."
curl -v https://firewall:443 --connect-timeout 5 || echo "Connexion bloquée (attendu)"





