# AutoDeploy Firewall (UFW + centralisation logs + Splunk)

## Objectif

Déployer automatiquement une infrastructure Docker comprenant :

- **`firewall`** : pare-feu Linux avec **UFW** (règles + `logging high`), envoi de logs au format UFW vers Splunk au démarrage
- **`splunk`** : supervision / recherche des logs (réception syslog UDP 514, dashboard fourni)
- **`client`** + **`attacker`** : conteneurs de test ; le **client** envoie les logs UFW vers Splunk (UDP 514) lors des tests

L’objectif final est de **visualiser dans Splunk** les événements UFW (BLOCK/ALLOW). Les logs sont envoyés par le **client** (script `test-rules-ufw.sh`) et le **firewall** (au démarrage) via `logger` vers Splunk en UDP 514.

## Architecture (conteneurs & réseaux)

### Conteneurs

| Service | Rôle |
|---|---|
| `firewall` | UFW + envoi de logs UFW vers Splunk au démarrage (UDP 514) |
| `splunk` | réception syslog UDP 514 + indexation + dashboard |
| `client` | tests des règles UFW + **envoi des logs UFW vers Splunk** (UDP 514) |
| `attacker` | tests (trafic bloqué par UFW) |

### Réseau Docker

- **Un seul réseau** `main_network` (10.20.0.0/16) : tous les conteneurs sont dessus. Le **client** et le **firewall** envoient les logs UFW vers Splunk (hostname `splunk`, port UDP 514). Voir `containers/CHAINE_LOGS.md` pour le détail.

## Prérequis

- Linux (Ubuntu/Debian recommandé)
- Accès `sudo`
- Docker & Docker Compose (ou installation automatique via le script)

## Déploiement (recommandé)

Depuis la racine du projet :

```bash
chmod +x deploy-all.sh
sudo ./deploy-all.sh
```

Ce script installe les dépendances si besoin, puis lance le déploiement.

## Accès Splunk

- **URL** : `http://localhost:8000`
- **Identifiants** : `admin` / `splunk1RT3`

L’image Splunk est construite avec la config (réception UDP 514, parsing UFW) et le **tableau de bord UFW** intégrés (`containers/splunk/Dockerfile`). Recherche : `index=main sourcetype=syslog UFW` ; dashboard : Recherche > Dashboards > UFW Firewall Dashboard.

## Tests (après déploiement)

Pour générer du trafic et **envoyer les logs UFW vers Splunk** :

```bash
docker exec client /usr/local/bin/test-rules-ufw.sh
```

Le script teste les règles UFW (ports 445, 3389, 139, 137, 22, 80) et envoie un log au format UFW vers Splunk (UDP 514) après chaque test. Ensuite, dans Splunk, fais une recherche du type :

- `index=main sourcetype=syslog UFW`
- ou filtrer : `UFW BLOCK` / `UFW ALLOW`

## Commandes utiles

```bash
docker ps
docker compose logs -f
docker exec firewall ufw status verbose
```

## Documentation

- `containers/CHAINE_LOGS.md` : **flux des logs** (client/firewall → Splunk, UDP 514)
- `DEPLOIEMENT.md` : guide détaillé (commandes, diagnostics)
- `STRUCTURE.md` : arborescence du projet
- `PROJET.md` : compte-rendu (contexte / choix / résultats)

