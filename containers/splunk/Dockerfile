# Image Splunk avec config UFW et tableau de bord intégrés
FROM splunk/splunk:latest

USER root

# Répertoires pour la config système et le dashboard
RUN mkdir -p /opt/splunk/etc/system/local \
    && mkdir -p /opt/splunk/etc/apps/search/local/data/ui/views

# Config réception syslog (UDP 514) et parsing UFW
COPY inputs.conf /opt/splunk/etc/system/local/inputs.conf
COPY props.conf   /opt/splunk/etc/system/local/props.conf
COPY dashboard_ufw.xml /opt/splunk/etc/apps/search/local/data/ui/views/ufw_firewall_dashboard.xml

# Droits pour l'utilisateur splunk (uid/gid classiques de l'image officielle)
RUN chown -R 41812:41812 /opt/splunk/etc/system/local /opt/splunk/etc/apps/search/local 2>/dev/null || \
    chown -R splunk:splunk /opt/splunk/etc/system/local /opt/splunk/etc/apps/search/local 2>/dev/null || true
