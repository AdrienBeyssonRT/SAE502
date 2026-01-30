# 🚀 Guide de Déploiement - AutoDeploy Firewall

## 📋 Vue d'ensemble

Ce guide explique comment déployer complètement le système de pare-feu automatisé avec supervision des logs. Le déploiement peut être effectué en **une seule commande** ou étape par étape.

## ⚡ Installation et déploiement automatique (RECOMMANDÉ)

### Tout faire en UNE SEULE COMMANDE

Si vous venez de cloner le projet, exécutez simplement :

```bash
sudo ./deploy-all.sh
```

**Cette commande unique fait TOUT automatiquement :**
1. ✅ Mise à jour du système (apt update && upgrade)
2. ✅ Installation de Python 3 et pip
3. ✅ Installation d'Ansible
4. ✅ Installation de Docker et Docker Compose
5. ✅ Installation des modules Python nécessaires
6. ✅ Configuration des permissions Docker
7. ✅ Reconstruction des conteneurs
8. ✅ Démarrage de l'infrastructure
9. ✅ Configuration UFW avec logging
10. ✅ Génération de trafic pour créer des logs
11. ✅ Vérification complète de la chaîne de logs
12. ✅ Affichage d'un résumé complet

**C'est tout !** À la fin, l'interface Splunk est disponible sur http://localhost:8000

---

## 📋 Installation étape par étape (optionnel)

Si vous préférez faire les étapes séparément :

### 1. Installation des dépendances manuellement

Installez manuellement : Python 3, pip, Ansible, Docker, Docker Compose

### 2. Déploiement

```bash
ansible-playbook ansible/playbooks/deploy-and-test.yml
```

## 📋 Déploiement manuel (si nécessaire)

### Prérequis

- Machine Linux (Ubuntu 22.04 recommandé)
- Python 3 avec pip
- Ansible 2.9+
- Docker et Docker Compose
- Accès sudo/root

### Installation en une commande

```bash
ansible-playbook ansible/playbooks/deploy-and-test.yml
```

**Cette commande unique fait automatiquement :**
1. ✅ Installation de Docker (si nécessaire)
2. ✅ Reconstruction de tous les conteneurs
3. ✅ Démarrage de l'infrastructure
4. ✅ Configuration UFW avec logging activé
5. ✅ Génération de trafic pour créer des logs
6. ✅ Vérification complète de la chaîne de logs
7. ✅ Vérification de la catégorisation (BLOCK/ALLOW)
8. ✅ Affichage d'un résumé avec statistiques

**Résultat :** Interface Splunk opérationnelle sur **http://localhost:8000** avec logs UFW indexés et analysables.

## 📦 Architecture déployée

### Conteneurs Docker

| Conteneur | Rôle | Réseau | Ports |
|-----------|------|--------|-------|
| **firewall** | Pare-feu UFW | main_network | - |
| **splunk** | Plateforme de supervision Splunk | main_network | 8000, 514/udp |
| **client** | Conteneur de test | main_network | - |
| **attacker** | Conteneur de test (trafic bloqué) | main_network | - |

### Réseau Docker

- `main_network` (10.20.0.0/16) : tous les conteneurs sont dessus (firewall, splunk, client, attacker) pour que le trafic et les logs fonctionnent.

## 🔄 Flux des logs

```
┌──────────┐                    ┌─────────────┐      ┌──────────────┐
│ Firewall │ ─────────────────>│   Splunk    │ ───> │ Interface Web│
│   UFW    │  UDP 514 (rsyslog) │  UDP 514    │ HTTP │  Port 8000   │
└──────────┘                    └─────────────┘      └──────────────┘
```

1. **Génération** : UFW génère des logs kernel dans le buffer noyau
2. **Envoi** : rsyslog (imklog) dans le firewall envoie les logs directement à Splunk via UDP 514
3. **Réception** : Splunk écoute sur UDP 514 et indexe les logs (sourcetype=syslog)
4. **Affichage** : L'interface web Splunk affiche les logs (recherche : `index=main sourcetype=syslog UFW`)

## 🔒 Règles UFW configurées

### Règles par défaut
- `deny incoming` : Blocage de tout le trafic entrant
- `allow outgoing` : Autorisation du trafic sortant
- `deny routed` : Blocage du routage non autorisé

### Services autorisés
- **SSH interne** : `allow from 10.20.0.0/16 to any port 22`
- **Envoi des logs** : `allow out 514/udp` (vers Splunk)
- **DNS sortant** : `allow out 53/udp` et `53/tcp`
- **Web sortant** : `allow out 80/tcp` et `443/tcp`

### Services bloqués
- **SMB/NetBIOS** : ports 137, 138, 139, 445
- **RDP** : port 3389
- **HTTP** : port 80 (pas de service, donc bloqué)

### Sécurité
- **Limitation SSH** : `limit 22/tcp` (protection brute-force)
- **Journalisation** : `logging high`

## 🧪 Tests automatiques

Le playbook `deploy-and-test.yml` génère automatiquement du trafic sur :

| Port | Action attendue | Catégorie |
|------|----------------|-----------|
| 445 | Bloqué | **BLOCK** |
| 3389 | Bloqué | **BLOCK** |
| 139 | Bloqué | **BLOCK** |
| 80 | Bloqué | **BLOCK** |
| 22 | Autorisé | **ALLOW** |

## 📊 Vérification du déploiement

### 1. Vérifier les conteneurs

```bash
docker ps
```

Vous devriez voir **4 conteneurs** : `firewall`, `splunk`, `client`, `attacker`.

> **Si vous voyez encore `logcollector`** : votre répertoire de projet contient une ancienne version. Le flux actuel est **firewall → Splunk** (sans logcollector). Mettez à jour les fichiers (git pull ou copie du dépôt), puis exécutez :
> ```bash
> docker compose down && docker compose up -d
> ```

### 2. Vérifier UFW

```bash
docker exec firewall ufw status verbose
```

Vérifiez que :
- `Status: active`
- `Logging: on (high)`

### 3. Vérifier les logs dans le firewall

```bash
docker exec firewall tail -30 /var/log/kern.log | grep -i ufw
```

Vous devriez voir des logs UFW avec `[UFW BLOCK]` ou `[UFW ALLOW]`.

### 4. Vérifier l'interface web

Ouvrez **http://localhost:8000** dans votre navigateur et connectez-vous avec :
- **Utilisateur** : `admin`
- **Mot de passe** : `splunk1RT3`

**Dashboard automatique** : Le dashboard UFW est automatiquement créé et disponible dans :
- Menu **Dashboards** → **UFW Firewall Dashboard**
- Ou directement via : http://localhost:8000/en-US/app/search/ufw_firewall_dashboard

Vous devriez voir :
- ✅ Statistiques (total logs, tentatives bloquées, connexions autorisées)
- ✅ Logs détaillés avec IP sources, ports, protocoles
- ✅ Catégorisation correcte (BLOCK, ALLOW, LIMIT)
- ✅ Top IP sources, top ports, répartition par protocole

### 5. Vérifier la recherche Splunk

```bash
# Statistiques
# Rechercher les logs UFW dans Splunk
docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog "UFW"' -auth admin:splunk1RT3

# Logs récents
# Rechercher les logs BLOCK
docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog "UFW BLOCK"' -auth admin:splunk1RT3

# Rechercher les logs ALLOW dans Splunk
docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog "UFW ALLOW"' -auth admin:splunk1RT3
```

## 🛠️ Déploiement étape par étape (optionnel)

Si vous préférez déployer manuellement :

### Étape 1 : Installation de Docker

```bash
ansible-playbook ansible/playbooks/install.yml
```

### Étape 2 : Déploiement de l'infrastructure

```bash
ansible-playbook ansible/playbooks/deploy.yml
```

### Étape 3 : Génération de trafic et vérification

```bash
# Exécuter les tests UFW (génère automatiquement des logs)
docker exec client /usr/local/bin/test-rules-ufw.sh

# Attendre 5 secondes pour que les logs remontent
sleep 5

# Vérifier les logs dans le firewall
docker exec firewall tail -30 /var/log/kern.log | grep -i ufw

# Diagnostic complet de la chaîne firewall → Splunk
./diagnostic-logs.sh
```

## 🔧 Commandes utiles

### Voir les logs en temps réel

```bash
# Logs UFW dans le firewall
docker exec firewall tail -f /var/log/kern.log | grep UFW

# Logs de tous les conteneurs
docker compose logs -f
```

### Tester manuellement

```bash
# Entrer dans le conteneur client
docker exec -it client bash

# Exécuter les tests UFW (génère automatiquement des logs)
/usr/local/bin/test-rules-ufw.sh
```

### Redémarrer l'infrastructure

```bash
docker-compose down
docker-compose up -d --build
```

### Mettre à jour les règles UFW

```bash
ansible-playbook ansible/playbooks/rules_update.yml
```

## 🐛 Dépannage

### Les conteneurs ne démarrent pas

```bash
# Vérifier les logs
docker-compose logs

# Vérifier l'état
docker-compose ps

# Redémarrer
docker-compose restart
```

### Aucun log UFW dans le firewall

1. Vérifier que UFW est actif :
   ```bash
   docker exec firewall ufw status verbose
   ```

2. Activer le logging si nécessaire :
   ```bash
   docker exec firewall ufw logging high
   ```

3. Générer du trafic via les tests :
   ```bash
   docker exec client /usr/local/bin/test-rules-ufw.sh
   ```

4. Vérifier immédiatement (dans les 2 secondes) :
   ```bash
   docker exec firewall tail -30 /var/log/kern.log | grep -i ufw
   ```

### Les logs ne remontent pas à Splunk

1. Vérifier que rsyslog fonctionne dans le firewall :
   ```bash
   docker exec firewall ps aux | grep rsyslog
   ```

2. Vérifier la connectivité firewall → Splunk :
   ```bash
   docker exec firewall ping -c 2 splunk
   ```

3. Lancer le script de diagnostic :
   ```bash
   ./diagnostic-logs.sh
   ```

4. Vérifier la config Splunk (entrée UDP 514) :
   ```bash
   docker exec splunk cat /opt/splunk/etc/system/local/inputs.conf | grep -A5 udp
   ```

### Les logs ne s'affichent pas dans Splunk

1. Vérifier que Splunk est en cours d'exécution :
   ```bash
   docker ps | grep splunk
   ```

2. Attendre 1 à 2 minutes après le démarrage (Splunk peut être lent à démarrer).

3. Recherche dans Splunk (CLI) :
   ```bash
   docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog UFW' -auth admin:splunk1RT3
   ```

### Les logs ne sont pas correctement catégorisés

1. Vérifier les logs bruts dans le firewall :
   ```bash
   docker exec firewall tail -20 /var/log/kern.log | grep UFW
   ```

2. Vérifier que les logs contiennent `[UFW BLOCK]` ou `[UFW ALLOW]`.

## 📈 Résultat attendu

Après le déploiement, vous devriez avoir :

- ✅ **4 conteneurs** en cours d'exécution (firewall, splunk, client, attacker)
- ✅ **UFW actif** avec logging high
- ✅ **Logs UFW** générés et envoyés par rsyslog (firewall) vers Splunk en UDP 514
- ✅ **Logs indexés** dans Splunk et analysables via l'interface web
- ✅ **Recherches** possibles : `index=main sourcetype=syslog UFW` pour filtrer par action (BLOCK, ALLOW), IP sources, ports

## 🔗 Liens utiles

- **Interface Splunk** : http://localhost:8000
  - Utilisateur : `admin`
  - Mot de passe : `splunk1RT3`
- **Recherche de logs UFW** :
  ```bash
  docker exec splunk /opt/splunk/bin/splunk search 'index=main sourcetype=syslog "UFW"' -auth admin:splunk1RT3
  ```

## 📚 Documentation complémentaire

- **[STRUCTURE.md](STRUCTURE.md)** : Structure complète du projet
- **[PROJET.md](PROJET.md)** : Compte rendu détaillé du projet

