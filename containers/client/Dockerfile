FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y nmap curl netcat-openbsd iputils-ping telnet dnsutils net-tools && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Scripts de test
COPY test_scripts /usr/local/bin/
COPY generate-traffic.sh /usr/local/bin/generate-traffic.sh
RUN chmod +x /usr/local/bin/*.sh

WORKDIR /root

# Script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]





