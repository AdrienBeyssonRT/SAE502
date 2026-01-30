FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y nmap curl netcat-openbsd iputils-ping telnet dnsutils net-tools bsdutils && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Scripts de test
COPY test-rules-ufw.sh /usr/local/bin/test-rules-ufw.sh
RUN chmod +x /usr/local/bin/*.sh

WORKDIR /root

# Script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]





