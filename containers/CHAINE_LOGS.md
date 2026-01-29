# Chaîne des logs : Firewall → Splunk (direct)

## Flux

```
UFW (kern.log) → rsyslog (firewall) --UDP 514--> Splunk (index main, sourcetype syslog)
```

- **Firewall** : `containers/firewall/rsyslog.conf` envoie `kern.*` et `kernel-ufw:*` vers **@@splunk:514** (UDP).
- **Splunk** : `containers/splunk/inputs.conf` écoute sur **UDP 514** (`[udp://514]`, `listen_on_ip = 0.0.0.0`).

## Réseaux Docker

- **firewall** et **splunk** sont sur **logs_network** → le nom `splunk` est résolu.
- Le logcollector a été retiré : envoi direct firewall → Splunk.

## Après modification des configs

```bash
docker compose build --no-cache firewall splunk
docker compose up -d
```

Puis générer du trafic et vérifier dans Splunk :

```bash
docker exec client /usr/local/bin/test-rules-ufw.sh
# Attendre 30 s à 1 min → recherche : index=main sourcetype=syslog UFW
```
