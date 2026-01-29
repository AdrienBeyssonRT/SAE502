#!/bin/bash
# À lancer une fois Splunk démarré (http://localhost:8000 accessible)
# Injecte inputs.conf, props.conf et le dashboard UFW dans le conteneur

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONTAINER="${1:-splunk}"

echo "Déploiement de la config Splunk dans le conteneur: $CONTAINER"

docker exec "$CONTAINER" mkdir -p /opt/splunk/etc/system/local
docker exec "$CONTAINER" mkdir -p /opt/splunk/etc/apps/search/local/data/ui/views

docker cp "$SCRIPT_DIR/inputs.conf" "$CONTAINER:/opt/splunk/etc/system/local/inputs.conf"
docker cp "$SCRIPT_DIR/props.conf" "$CONTAINER:/opt/splunk/etc/system/local/props.conf"
docker cp "$SCRIPT_DIR/dashboard_ufw.xml" "$CONTAINER:/opt/splunk/etc/apps/search/local/data/ui/views/ufw_firewall_dashboard.xml"

docker exec "$CONTAINER" chown -R splunk:splunk /opt/splunk/etc/system/local /opt/splunk/etc/apps/search/local

echo "Redémarrage de Splunk pour appliquer la config..."
docker restart "$CONTAINER"

echo "OK. Attendre 1–2 min puis: http://localhost:8000 (admin / splunk1RT3)"
echo "Recherche UFW: index=main sourcetype=syslog UFW"
