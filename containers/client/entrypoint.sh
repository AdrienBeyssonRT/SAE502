#!/bin/bash
# Script d'entrée pour le conteneur client

echo "Conteneur client prêt pour les tests"
echo "Outils disponibles: nmap, curl, nc, ping, telnet"
echo ""
echo "Exemples de commandes:"
echo "  - nmap -p 22,80,443,445 firewall"
echo "  - curl http://firewall:80"
echo "  - nc -zv firewall 22"
echo "  - ping firewall"
echo ""

# Garder le conteneur actif
exec /bin/bash





