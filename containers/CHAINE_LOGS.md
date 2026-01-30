# Chaîne des logs UFW → Splunk

## Flux fonctionnel (logs reçus par Splunk)

Les logs UFW visibles dans Splunk proviennent de **deux sources** qui envoient en **UDP 514** vers Splunk :

```
1) Client (test-rules-ufw.sh)  →  logger -n splunk -P 514  →  Splunk (UDP 514)
2) Firewall (entrypoint.sh)    →  logger -n splunk -P 514  →  Splunk (UDP 514)
```

- **Client** : à chaque exécution de `test-rules-ufw.sh`, le script envoie des messages au format `[UFW BLOCK]` / `[UFW ALLOW]` avec SRC, DST, DPT, PROTO vers Splunk (UDP 514).
- **Firewall** : au démarrage, le conteneur envoie 2 logs au format UFW vers Splunk pour vérifier la chaîne.
- **Splunk** : écoute sur `0.0.0.0:514/udp` (`inputs.conf`), sourcetype `syslog`, et parse les champs UFW via `props.conf`.

## Pourquoi pas les logs noyau (kern.log) ?

Dans un conteneur Docker, les logs **noyau** (netfilter/UFW) ne remontent en général **pas** dans `/dev/kmsg` du conteneur ni dans le `dmesg` de l’hôte. Le trafic est bien filtré par UFW (compteurs iptables), mais aucun log UFW n’apparaît côté noyau. D’où l’envoi des logs **applicatifs** au format UFW depuis le client et le firewall via `logger` vers Splunk.

## Réseau

- **main_network** (10.20.0.0/16) : firewall, splunk, client, attacker.
- Le hostname `splunk` est résolu sur ce réseau → tous les conteneurs peuvent envoyer en UDP 514 à `splunk:514`.

## Générer des logs et vérifier dans Splunk

1. **Générer des logs** (depuis l’hôte) :
   ```bash
   docker exec client /usr/local/bin/test-rules-ufw.sh
   ```

2. **Vérifier dans Splunk** :
   - URL : http://localhost:8000 (admin / splunk1RT3)
   - Recherche : `index=main sourcetype=syslog UFW`
   - Ou : `index=main UFW BLOCK` / `index=main UFW ALLOW`

3. **Test minimal (un seul message)** :
   ```bash
   docker exec client logger -n splunk -P 514 -d "[UFW BLOCK] IN=eth0 OUT= MAC= SRC=10.20.0.4 DST=10.20.0.2 DPT=445 PROTO=TCP"
   ```
   Puis dans Splunk : `index=main sourcetype=syslog UFW DPT=445`.

## Fichiers concernés

| Fichier | Rôle |
|--------|------|
| `containers/client/test-rules-ufw.sh` | Envoie les logs UFW (BLOCK/ALLOW) vers Splunk après chaque test de règle |
| `containers/client/Dockerfile` | Installe `bsdutils` (commande `logger`) |
| `containers/firewall/entrypoint.sh` | Envoie 2 logs UFW au démarrage vers Splunk |
| `containers/firewall/Dockerfile` | Installe `bsdutils` (commande `logger`) |
| `containers/splunk/inputs.conf` | Écoute UDP 514, sourcetype syslog |
| `containers/splunk/props.conf` | Extraction des champs UFW (action, SRC, DST, DPT, PROTO) |

## Après modification

```bash
docker compose build --no-cache client firewall splunk
docker compose up -d
docker exec client /usr/local/bin/test-rules-ufw.sh
# Puis vérifier dans Splunk : index=main sourcetype=syslog UFW
```
