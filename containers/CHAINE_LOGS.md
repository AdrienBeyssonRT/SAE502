# Chaîne des logs : Firewall → Logcollector → Splunk

## 1. Splunk : réception syslog UDP 514

- **Fichier** : `containers/splunk/inputs.conf`
- **Config** : `[udp://514]` avec `listen_on_ip = 0.0.0.0`
- **Résultat** : Splunk écoute sur **toutes les interfaces** sur le port **UDP 514** (syslog).

## 2. Firewall → Logcollector

- **Firewall** (`containers/firewall/rsyslog.conf`) :
  - Lit `/var/log/kern.log` (logs UFW).
  - Envoie en **UDP** vers `logcollector:514` (`@@logcollector:514`).
- **Réseau** : firewall et logcollector sont sur **logs_network** → le nom `logcollector` est résolu.

## 3. Logcollector → Splunk

- **Logcollector** (`containers/logcollector/rsyslog.conf`) :
  - Reçoit en **UDP** sur le port **514** (`$UDPServerRun 514`, `$UDPServerAddress 0.0.0.0`).
  - Stocke dans `/var/log/firewall/`.
  - Réenvoie en **UDP** vers `splunk:514` (`@@splunk:514`).
- **Réseau** : logcollector et splunk sont sur **logs_network** et **supervision_network** → le nom `splunk` est résolu.

## 4. Réseaux Docker (docker-compose.yml)

| Conteneur    | Réseaux                    | Peut joindre        |
|-------------|----------------------------|----------------------|
| firewall    | firewall_network, logs_network | logcollector (logs_network) |
| logcollector| logs_network, supervision_network | firewall, splunk     |
| splunk      | logs_network, supervision_network | logcollector         |

## Résumé

```
UFW (kern.log) → rsyslog (firewall) --UDP 514--> logcollector --UDP 514--> Splunk (index main, sourcetype syslog)
```

## Après modification des configs

Reconstruire les images concernées et redémarrer :

```bash
docker compose build --no-cache firewall logcollector splunk
docker compose up -d
```

Puis générer du trafic et vérifier :

```bash
docker exec client /usr/local/bin/test-rules-ufw.sh
# Attendre 30 s à 1 min, puis dans Splunk : index=main sourcetype=syslog UFW
```
