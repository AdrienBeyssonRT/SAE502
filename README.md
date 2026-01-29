# AutoDeploy Firewall (UFW + centralisation logs + Splunk)

## Objectif

Déployer automatiquement une infrastructure Docker comprenant :

- **`firewall`** : pare-feu Linux avec **UFW** (règles + `logging high`), envoi des logs kernel vers Splunk en UDP 514
- **`splunk`** : supervision / recherche des logs (réception syslog UDP 514, dashboard fourni)
- **`client`** + **`attacker`** : conteneurs de test (outils réseau + script de test)

L’objectif final est de **visualiser dans Splunk** les événements UFW (BLOCK/ALLOW) suite à des tests réseau.

## Architecture (conteneurs & réseaux)

### Conteneurs

| Service | Rôle |
|---|---|
| `firewall` | UFW + envoi des logs kernel vers Splunk (UDP 514) |
| `splunk` | réception syslog UDP 514 + indexation + dashboard |
| `client` | tests internes (réseau `firewall_network`) |
| `attacker` | tests externes (réseau `tests_network`) |

### Réseaux Docker

- `firewall_network` : `firewall` ↔ `client`
- `logs_network` : `firewall` ↔ `splunk`
- `supervision_network` : `splunk`
- `tests_network` : `client` / `attacker`

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

Pour générer du trafic et déclencher des logs UFW :

```bash
docker exec client /usr/local/bin/test-rules-ufw.sh
```

Ensuite, dans Splunk, fais une recherche du type :

- `index=main sourcetype=syslog UFW`
- ou filtrer : `UFW BLOCK` / `UFW ALLOW`

## Commandes utiles

```bash
docker ps
docker compose logs -f
docker exec firewall ufw status verbose
```

## Documentation

- `DEPLOIEMENT.md` : guide détaillé (commandes, diagnostics)
- `STRUCTURE.md` : arborescence du projet
- `PROJET.md` : compte-rendu (contexte / choix / résultats)

