# Chaîne des logs : Firewall → Splunk (direct)

## Flux

```
UFW (kern.log) → rsyslog (firewall) --UDP 514--> Splunk (index main, sourcetype syslog)
```

- **Firewall** : `containers/firewall/rsyslog.conf` envoie `kern.*` vers **@splunk:514** (UDP).
- **Splunk** : `containers/splunk/inputs.conf` écoute sur **UDP 514** (`[udp://514]`, `listen_on_ip = 0.0.0.0`).

## Réseau Docker

- **Un seul réseau** `main_network` (172.20.0.0/16) : **firewall**, **splunk**, **client**, **attacker** sont tous dessus.
- Le nom `splunk` est résolu sur ce réseau → le firewall envoie les logs en UDP 514 à Splunk.
- Envoi direct firewall → Splunk (pas de logcollector).

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
