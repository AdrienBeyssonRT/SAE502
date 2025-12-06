FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y ufw rsyslog net-tools iputils-ping curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Configure rsyslog to forward logs
COPY rsyslog.conf /etc/rsyslog.conf

# Créer le répertoire rsyslog et les fichiers de logs
RUN mkdir -p /var/lib/rsyslog && \
    chmod 755 /var/lib/rsyslog && \
    touch /var/log/ufw.log /var/log/kern.log && \
    chmod 644 /var/log/ufw.log /var/log/kern.log

# Copy UFW rules script
COPY setup-ufw.sh /usr/local/bin/setup-ufw.sh
RUN chmod +x /usr/local/bin/setup-ufw.sh

# Expose ports for testing
EXPOSE 22 80 443

# Start script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]



