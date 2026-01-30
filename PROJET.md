# 📊 Compte Rendu du Projet - AutoDeploy Firewall

## 🎯 Objectif du projet

Automatiser le déploiement complet d'un pare-feu Linux (UFW), centraliser ses journaux et les analyser via un outil de supervision graphique. L'ensemble doit être déployable via Ansible, sans intervention manuelle.

## ✅ Conformité au cahier des charges

### Infrastructure technique

- ✅ **4 conteneurs Docker** :
  - `firewall` : Pare-feu UFW avec règles de sécurité (rsyslog envoie les logs à Splunk)
  - `splunk` : Plateforme de supervision (réception UDP 514, interface web)
  - `client` : Conteneur de test avec outils réseau
  - `attacker` : Conteneur pour générer du trafic bloqué

- ✅ **1 réseau Docker** : `main_network` (10.20.0.0/16) — tous les conteneurs (firewall, splunk, client, attacker) sont dessus pour que le trafic et les logs fonctionnent.

### Services fonctionnels

- ✅ **Firewall** : UFW configuré avec toutes les règles spécifiées ; rsyslog envoie les logs à Splunk
- ✅ **Splunk** : Réception des logs en UDP 514, interface web (port 8000), tableaux de bord UFW
- ✅ **Client** : Outils de test (nmap, curl, nc, ping)

### Règles UFW implémentées

- ✅ `deny incoming`, `allow outgoing`, `deny routed`
- ✅ SSH interne : `allow from 10.20.0.0/16 to any port 22`
- ✅ Envoi logs : `allow out 514/udp`
- ✅ DNS sortant : `allow out 53`
- ✅ Web sortant : `allow out 80/tcp et 443/tcp`
- ✅ Blocage SMB/NetBIOS : ports 137, 138, 139, 445
- ✅ Blocage RDP : port 3389
- ✅ Limitation SSH : `limit 22/tcp`
- ✅ Journalisation : `logging high`

### Rôles Ansible

- ✅ **docker** : Installation Docker + préparation système
- ✅ **firewall** : Construction image + configuration UFW
- ✅ **splunk** : Image Splunk avec entrée UDP 514 et dashboard UFW
- ✅ **client** : Installation outils de test
- ✅ **docker_compose** : Orchestration complète

### Playbooks Ansible

- ✅ **install.yml** : Installation Docker
- ✅ **deploy.yml** : Déploiement complet
- ✅ **rules_update.yml** : Modification dynamique des règles
- ✅ **tests.yml** : Tests automatiques + vérification logs

### Automatisation complète

- ✅ Déploiement sans intervention manuelle
- ✅ Configuration automatique via Ansible
- ✅ Tests automatisés
- ✅ Mise à jour dynamique des règles UFW

## 🏗️ Architecture technique

### Schéma de l'infrastructure

```
┌─────────────────────────────────────────────────────────┐
│                    Machine Virtuelle                    │
│                                                         │
│  ┌──────────┐                    ┌─────────────┐      │
│  │ Firewall │ ──────────────────▶│   Splunk    │      │
│  │  (UFW)   │  UDP 514 (rsyslog) │  (port 8000)│      │
│  └────┬─────┘                    └─────────────┘      │
│       │                                                 │
│  ┌────▼─────┐    ┌──────────┐                          │
│  │  Client  │    │ Attacker  │                          │
│  │ (tests)  │    │ (trafic)  │                          │
│  └──────────┘    └──────────┘                          │
│                                                         │
│  Réseau: main_network (tous les conteneurs)             │
└─────────────────────────────────────────────────────────┘
```

### Flux de données

1. **Génération de trafic** : Le conteneur client (ou attacker) génère du trafic vers le firewall
2. **Filtrage** : UFW applique les règles ; les logs kernel (dont UFW) sont captés par rsyslog (imklog)
3. **Envoi** : rsyslog dans le firewall envoie les logs directement à Splunk en UDP 514
4. **Indexation** : Splunk reçoit sur UDP 514 et indexe (sourcetype=syslog)
5. **Visualisation** : L'utilisateur consulte les logs et le dashboard UFW sur http://localhost:8000

## 🔧 Technologies utilisées

### Automatisation
- **Ansible** : Orchestration et configuration automatique
- **Docker** : Conteneurisation des services
- **Docker Compose** : Orchestration des conteneurs

### Sécurité
- **UFW** : Pare-feu Linux avec règles configurables
- **rsyslog** : Centralisation et sécurisation des logs

### Supervision
- **Flask** : Framework web Python
- **HTML/CSS/JavaScript** : Interface utilisateur moderne
- **API REST** : Endpoints pour récupérer les données

### Outils de test
- **nmap** : Scan de ports
- **curl** : Tests HTTP
- **netcat** : Tests de connexion TCP/UDP
- **ping** : Tests de connectivité

## 📈 Fonctionnalités implémentées

### Pare-feu
- Configuration automatique via Ansible
- Règles de sécurité complètes
- Journalisation haute (high)
- Mise à jour dynamique des règles

### Collecte de logs
- Réception UDP sur le port 514
- Stockage structuré par date
- Filtrage des logs système
- Partage via volume Docker

### Supervision
- Interface web moderne et responsive
- Tableaux de bord en temps réel
- Statistiques agrégées (IP sources, ports, actions)
- Actualisation automatique (5 secondes)
- API REST pour intégration

### Tests
- Conteneur dédié avec outils réseau
- Scripts de test automatisés
- Vérification des règles UFW
- Validation de la chaîne de logs

## 🧪 Scénarios de test

### Scénario 1 : Test de blocage
1. Client tente une connexion sur le port 445 (SMB)
2. UFW bloque la connexion
3. Log généré avec action `[UFW BLOCK]`
4. Log apparaît dans la supervision en quelques secondes

### Scénario 2 : Test d'autorisation
1. Client tente une connexion SSH depuis le réseau interne
2. UFW autorise (règle allow from 10.20.0.0/16)
3. Log généré avec action `[UFW ALLOW]`
4. Log visible dans la supervision

### Scénario 3 : Mise à jour dynamique
1. Exécution de `rules_update.yml`
2. Script UFW régénéré avec nouvelles règles
3. Image firewall reconstruite
4. Conteneur redémarré avec nouvelles règles
5. Tests automatiques vérifient le bon fonctionnement

## 📊 Métriques de supervision

L'application de supervision affiche :
- **Total logs** : Nombre total d'événements
- **Tentatives bloquées** : Connexions refusées par UFW
- **Connexions autorisées** : Trafic autorisé
- **IP sources** : Nombre d'adresses IP uniques
- **Détails par log** : IP source, destination, protocole, port, action

## 🔐 Sécurité

- Isolation réseau via Docker networks
- Pare-feu avec règles restrictives
- Protection brute-force sur SSH
- Journalisation complète pour audit
- Pas d'exposition de ports sensibles vers l'extérieur

## 🚀 Déploiement

Le projet peut être déployé en 2 commandes :
```bash
ansible-playbook ansible/playbooks/install.yml
ansible-playbook ansible/playbooks/deploy.yml
```

Tout est automatisé, aucune intervention manuelle requise.

## 📝 Résultats

### Points forts
- ✅ Déploiement entièrement automatisé
- ✅ Infrastructure complète et fonctionnelle
- ✅ Supervision visuelle en temps réel
- ✅ Tests automatisés intégrés
- ✅ Documentation complète

### Difficultés rencontrées
- Configuration rsyslog pour l'envoi/réception des logs
- Parsing des logs UFW (formats variés)
- Gestion des erreurs Python 3.13 avec pip
- Filtrage des logs système rsyslog

### Solutions apportées
- Simplification de la configuration rsyslog
- Amélioration du parsing avec détection multiple de formats
- Utilisation de `--break-system-packages` pour pip
- Filtrage intelligent des logs dans l'application

## 🎓 Conclusion

Le projet AutoDeploy Firewall répond à 100% aux exigences du cahier des charges :
- ✅ Infrastructure complète avec 4 conteneurs
- ✅ Réseaux Docker dédiés
- ✅ Pare-feu opérationnel avec toutes les règles
- ✅ Centralisation des logs
- ✅ Supervision visuelle
- ✅ Client de test
- ✅ Automatisation complète via Ansible
- ✅ Tests automatisés
- ✅ Mise à jour dynamique des règles

Le projet est prêt pour la démonstration et l'évaluation. Il constitue une solution complète, cohérente et entièrement automatisable pour le déploiement et la supervision d'un pare-feu Linux.

## 📚 Documentation du projet

- **DEPLOIEMENT.md** : Guide complet de déploiement avec toutes les explications
- **STRUCTURE.md** : Arborescence complète et description des composants
- **PROJET.md** : Ce compte rendu détaillé

## 👥 Auteurs

Projet SAÉ 5.02 - AutoDeploy Firewall

## 📄 Licence

Ce projet est réalisé dans le cadre académique.


