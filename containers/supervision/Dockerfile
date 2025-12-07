FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y python3 python3-pip python3-flask python3-pandas net-tools curl && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Installer les dépendances Python
COPY requirements.txt /tmp/requirements.txt
RUN pip3 install -r /tmp/requirements.txt && \
    rm /tmp/requirements.txt

# Copier l'application de supervision
COPY supervision_app.py /app/supervision_app.py
COPY templates /app/templates
COPY static /app/static

WORKDIR /app

# Exposer le port web
EXPOSE 5000

# Script d'entrée
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]





