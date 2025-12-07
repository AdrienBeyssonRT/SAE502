# 📁 Structure du Projet AutoDeploy Firewall

## Arborescence complète

```
SAE502 final/
│
├── ansible.cfg                    # Configuration Ansible
├── docker-compose.yml             # Orchestration des conteneurs Docker
├── README.md                      # Documentation principale du projet
├── INSTALLATION.md                # Guide d'installation détaillé
├── STRUCTURE.md                   # Ce fichier - Structure du projet
├── PROJET.md                      # Compte rendu du projet
├── .gitignore                     # Fichiers à ignorer par Git
│
├── ansible/                       # Configuration Ansible
│   ├── inventory                  # Inventaire Ansible (localhost)
│   │
│   ├── playbooks/                 # Playbooks Ansible
│   │   ├── install.yml            # Installation Docker et préparation système
│   │   ├── deploy.yml             # Déploiement complet de l'infrastructure
│   │   ├── rules_update.yml       # Mise à jour dynamique des règles UFW
│   │   └── tests.yml              # Tests automatiques du pare-feu
│   │
│   └── roles/                     # Rôles Ansible
│       ├── docker/                # Rôle : Installation Docker
│       │   ├── defaults/main.yml  # Variables par défaut
│       │   └── tasks/main.yml     # Tâches d'installation
│       │
│       ├── firewall/              # Rôle : Configuration pare-feu
│       │   ├── defaults/main.yml  # Variables par défaut
│       │   ├── tasks/main.yml     # Construction de l'image Docker
│       │   └── templates/
│       │       └── setup-ufw.sh.j2  # Template des règles UFW
│       │
│       ├── logcollector/          # Rôle : Collecteur de logs
│       │   ├── defaults/main.yml
│       │   └── tasks/main.yml
│       │
│       ├── supervision/           # Rôle : Application de supervision
│       │   ├── defaults/main.yml
│       │   └── tasks/main.yml
│       │
│       ├── client/                # Rôle : Conteneur client de test
│       │   ├── defaults/main.yml
│       │   └── tasks/main.yml
│       │
│       └── docker_compose/       # Rôle : Orchestration Docker
│           ├── defaults/main.yml
│           └── tasks/main.yml
│
└── containers/                    # Conteneurs Docker
    │
    ├── firewall/                  # Conteneur pare-feu UFW
    │   ├── Dockerfile             # Image Docker du pare-feu
    │   ├── entrypoint.sh          # Script de démarrage
    │   ├── rsyslog.conf           # Configuration rsyslog (envoi logs)
    │   └── setup-ufw.sh           # Script de configuration UFW
    │
    ├── logcollector/              # Conteneur collecteur de logs
    │   ├── Dockerfile
    │   ├── entrypoint.sh
    │   └── rsyslog.conf           # Configuration rsyslog serveur
    │
    ├── supervision/               # Conteneur application de supervision
    │   ├── Dockerfile
    │   ├── entrypoint.sh
    │   ├── requirements.txt       # Dépendances Python
    │   ├── supervision_app.py     # Application Flask
    │   ├── templates/
    │   │   └── dashboard.html     # Interface web
    │   └── static/
    │       └── style.css          # Styles CSS
    │
    └── client/                    # Conteneur client de test
        ├── Dockerfile
        ├── entrypoint.sh
        └── test_scripts/          # Scripts de test
            ├── test_ssh.sh
            ├── test_ports.sh
            └── test_web.sh
```

## Description des composants

### Configuration Ansible

- **ansible.cfg** : Configuration globale (inventory, roles_path, become)
- **inventory** : Définit localhost comme cible de déploiement

### Playbooks

- **install.yml** : Installe Docker et prépare le système
- **deploy.yml** : Déploie toute l'infrastructure (images + conteneurs)
- **rules_update.yml** : Met à jour dynamiquement les règles UFW
- **tests.yml** : Exécute des tests automatiques et vérifie les logs

### Rôles Ansible

Chaque rôle suit la structure standard Ansible :
- `defaults/` : Variables par défaut
- `tasks/` : Tâches à exécuter
- `templates/` : Templates Jinja2 (si nécessaire)

### Conteneurs Docker

Chaque conteneur contient :
- **Dockerfile** : Définition de l'image Docker
- **entrypoint.sh** : Script de démarrage du conteneur
- **Fichiers de configuration** : Spécifiques à chaque service

## Flux de déploiement

1. **install.yml** → Installe Docker sur la machine
2. **deploy.yml** → 
   - Construit les images Docker de tous les conteneurs
   - Lance l'infrastructure complète via docker-compose
   - Configure automatiquement UFW avec les règles
3. **rules_update.yml** → Met à jour les règles UFW si nécessaire
4. **tests.yml** → Vérifie le bon fonctionnement

## Réseaux Docker

Définis dans `docker-compose.yml` :
- `firewall_network` (172.20.0.0/16) : Réseau pour le firewall et le client
- `logs_network` (172.21.0.0/16) : Réseau pour le firewall et le logcollector
- `supervision_network` (172.22.0.0/16) : Réseau pour le logcollector et la supervision
- `tests_network` (172.23.0.0/16) : Réseau pour les tests

## Points d'entrée

- **Supervision web** : http://localhost:5000
- **Client de test** : `docker exec -it client bash`
- **Logs** : `docker-compose logs -f`
- **Règles UFW** : `docker exec firewall ufw status verbose`

## Technologies utilisées

- **Ansible** : Automatisation du déploiement
- **Docker** : Conteneurisation des services
- **Docker Compose** : Orchestration des conteneurs
- **UFW** : Pare-feu Linux
- **rsyslog** : Collecte et centralisation des logs
- **Flask** : Application web de supervision
- **Python** : Langage de l'application de supervision


