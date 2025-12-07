#!/bin/bash
# Script d'entrée pour le conteneur supervision

set -e

echo "Démarrage de l'application de supervision..."

# Attendre que le volume de logs soit monté
if [ ! -d "/mnt/logs/firewall" ]; then
    echo "Création du répertoire de logs..."
    mkdir -p /mnt/logs/firewall
fi

# Démarrer l'application Flask
echo "Démarrage de l'application Flask..."
cd /app
python3 supervision_app.py





