# 📁 Structure du Projet AutoDeploy Firewall

## Arborescence complète

```
SAE502 final/
│
├── ansible.cfg                    # Configuration Ansible
├── docker-compose.yml             # Orchestration des conteneurs Docker
├── deploy-all.sh                  # Script unique : installation + déploiement + tests
├── DEPLOIEMENT.md                 # Guide complet de déploiement
├── STRUCTURE.md                   # Ce fichier - Structure du projet
├── PROJET.md                      # Compte rendu du projet
│
    ├── ansible/                       # Configuration Ansible
    │   ├── inventory                  # Inventaire Ansible (localhost)
    │   │
    │   └── playbooks/                 # Playbooks Ansible
    │       └── deploy-and-test.yml    # Déploiement complet avec tests automatiques
│
└── containers/                    # Conteneurs Docker
    │
    ├── firewall/                  # Conteneur pare-feu UFW
    │   ├── Dockerfile             # Image Docker du pare-feu
    │   ├── entrypoint.sh          # Script de démarrage
    │   ├── rsyslog.conf           # Configuration rsyslog (envoi logs)
    │   └── setup-ufw.sh           # Script de configuration UFW
    │
    │   # logcollector retiré : envoi direct firewall → Splunk
    │
    ├── splunk/                    # Conteneur Splunk pour supervision
    │   ├── inputs.conf            # Configuration réception syslog (UDP 514)
    │   ├── props.conf             # Configuration parsing logs UFW
    │   └── dashboard_ufw.xml      # Dashboard automatique UFW (chargé au démarrage)
    │
    └── client/                    # Conteneur client de test
        ├── Dockerfile
        ├── entrypoint.sh
        └── test-rules-ufw.sh      # Script de test des règles UFW (génère des logs)
```

## Description des composants

### Configuration Ansible

- **ansible.cfg** : Configuration globale (inventory, roles_path, become)
- **inventory** : Définit localhost comme cible de déploiement

### Playbooks

- **deploy-and-test.yml** : Déploiement complet avec tests automatiques et vérification
  - Construit les images Docker de tous les conteneurs
  - Lance l'infrastructure complète via docker-compose
  - Configure automatiquement UFW avec les règles
  - Génère du trafic et vérifie les logs
  - Vérifie l'intégration avec Splunk

### Scripts d'automatisation

- **deploy-all.sh** : Script unique qui fait tout automatiquement :
  - Installation des dépendances (Python, Ansible, Docker)
  - Mise à jour du système
  - Déploiement complet via Ansible
  - Tests et vérifications

### Conteneurs Docker

Chaque conteneur contient :
- **Dockerfile** : Définition de l'image Docker
- **entrypoint.sh** : Script de démarrage du conteneur
- **Fichiers de configuration** : Spécifiques à chaque service

## Flux de déploiement

### Méthode automatique (recommandée)

1. **deploy-all.sh** → Fait tout automatiquement :
   - Installe toutes les dépendances (Python, Ansible, Docker)
   - Met à jour le système
   - Exécute `deploy-and-test.yml` pour déployer et tester

### Méthode manuelle

1. Installer manuellement : Python 3, pip, Ansible, Docker, Docker Compose
2. **deploy-and-test.yml** → 
   - Construit les images Docker de tous les conteneurs
   - Lance l'infrastructure complète via docker-compose
   - Configure automatiquement UFW avec les règles
   - Génère du trafic et vérifie les logs
   - Vérifie l'intégration avec Splunk

## Réseau Docker

Défini dans `docker-compose.yml` :
- `main_network` (172.20.0.0/16) : tous les conteneurs (firewall, splunk, client, attacker) sont sur ce réseau pour que le trafic circule et que les logs remontent à Splunk.

## Points d'entrée

- **Interface Splunk** : http://localhost:8000 (admin / splunk1RT3)
- **Client de test** : `docker exec -it client bash`
- **Logs** : `docker-compose logs -f`
- **Règles UFW** : `docker exec firewall ufw status verbose`

## Technologies utilisées

- **Ansible** : Automatisation du déploiement
- **Docker** : Conteneurisation des services
- **Docker Compose** : Orchestration des conteneurs
- **UFW** : Pare-feu Linux
- **rsyslog** : Collecte et centralisation des logs
- **Splunk** : Plateforme de supervision et analyse de logs
- **Syslog** : Protocole de réception des logs (UDP 514)


