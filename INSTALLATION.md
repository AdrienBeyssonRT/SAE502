# 📖 Guide d'Installation Complet - AutoDeploy Firewall

## 🎯 Prérequis

Avant de commencer, vous devez avoir :

1. **Une machine virtuelle Linux** (Ubuntu 22.04 recommandé)
   - Ou un serveur Linux
   - Ou WSL2 sur Windows

2. **Python 3 installé**
   ```bash
   python3 --version
   # Doit afficher Python 3.x.x
   ```

3. **Accès sudo/root** sur la machine

4. **Connexion Internet** (pour télécharger les paquets)

---

## 📥 Étape 1 : Transférer le projet sur la machine Linux

### Option A : Si vous êtes déjà sur Linux
Le projet est déjà là, passez à l'étape 2.

### Option B : Depuis Windows vers Linux
Utilisez SCP, WinSCP, ou copiez les fichiers manuellement :
```bash
# Depuis Windows (PowerShell ou CMD)
scp -r "C:\Users\AdriT\Desktop\SAE502 final" user@votre-machine-linux:/home/user/
```

### Option C : Cloner depuis Git (si vous avez un dépôt)
```bash
git clone <votre-repo>
cd SAE502\ final
```

---

## 🔧 Étape 2 : Installer Ansible

Sur votre machine Linux, installez Ansible :

```bash
# Sur Ubuntu/Debian
sudo apt update
sudo apt install -y ansible python3-pip

# Vérifier l'installation
ansible --version
```

Si Ansible n'est pas disponible dans les dépôts :
```bash
sudo apt install -y software-properties-common
sudo apt-add-repository --yes --update ppa:ansible/ansible
sudo apt install -y ansible
```

---

## 🐳 Étape 3 : Installer Docker (via Ansible)

Cette étape installe Docker automatiquement :

```bash
# Aller dans le répertoire du projet
cd "SAE502 final"

# Exécuter le playbook d'installation
ansible-playbook ansible/playbooks/install.yml
```

**Ce que fait cette commande :**
- Installe Docker
- Installe docker-compose
- Installe les modules Python nécessaires
- Démarre le service Docker
- Ajoute votre utilisateur au groupe docker

**⏱️ Durée :** 2-5 minutes

**✅ Vérification :**
```bash
docker --version
docker-compose --version
```

Si vous voyez les versions, c'est bon ! Sinon, relancez la commande avec `sudo` :
```bash
sudo ansible-playbook ansible/playbooks/install.yml
```

---

## 🚀 Étape 4 : Déployer l'infrastructure complète

Une fois Docker installé, déployez tous les conteneurs :

```bash
# Toujours dans le répertoire du projet
ansible-playbook ansible/playbooks/deploy.yml
```

**Ce que fait cette commande :**
1. Construit les images Docker pour :
   - Le pare-feu (firewall)
   - Le collecteur de logs (logcollector)
   - L'application de supervision (supervision)
   - Le client de test (client)

2. Lance tous les conteneurs avec docker-compose

3. Configure automatiquement UFW avec les règles de sécurité

**⏱️ Durée :** 5-10 minutes (première fois, car il faut construire les images)

**✅ Vérification :**
```bash
# Voir les conteneurs en cours d'exécution
docker ps

# Vous devriez voir 4 conteneurs :
# - firewall
# - logcollector
# - supervision
# - client
```

Si certains conteneurs ne démarrent pas, vérifiez les logs :
```bash
docker-compose logs
```

---

## 🌐 Étape 5 : Accéder à la supervision

Une fois le déploiement terminé, ouvrez votre navigateur :

**URL :** http://localhost:5000

ou si vous êtes sur une machine distante :

**URL :** http://IP-DE-VOTRE-MACHINE:5000

**Vous devriez voir :**
- Un tableau de bord avec des statistiques
- Des logs en temps réel du pare-feu
- Des graphiques et informations sur les connexions

**Si la page ne charge pas :**
```bash
# Vérifier que le conteneur supervision tourne
docker ps | grep supervision

# Vérifier les logs
docker logs supervision

# Vérifier que le port est bien exposé
sudo netstat -tlnp | grep 5000
```

---

## 🧪 Étape 6 : Tester le pare-feu

### Option A : Depuis le conteneur client

```bash
# Entrer dans le conteneur client
docker exec -it client bash

# Une fois dans le conteneur, tester :
# Test de ping
ping -c 3 firewall

# Scan de ports
nmap -p 22,80,443,445 firewall

# Test SSH (devrait fonctionner depuis le réseau interne)
nc -zv firewall 22

# Test HTTP (devrait être bloqué)
curl http://firewall:80

# Test SMB (devrait être bloqué)
nc -zv firewall 445

# Sortir du conteneur
exit
```

### Option B : Tests automatiques

```bash
# Lancer les tests automatiques
ansible-playbook ansible/playbooks/tests.yml
```

Ce playbook va :
- Faire des tests de connexion
- Vérifier que les règles fonctionnent
- Afficher les logs générés
- Vérifier que la supervision reçoit les données

---

## 📊 Étape 7 : Voir les logs

### Logs de tous les conteneurs
```bash
docker-compose logs -f
```

### Logs du firewall uniquement
```bash
docker-compose logs -f firewall
```

### Logs dans le collecteur
```bash
docker exec logcollector tail -f /var/log/firewall/*.log
```

### Vérifier les règles UFW
```bash
docker exec firewall ufw status verbose
```

---

## 🔄 Commandes utiles

### Redémarrer l'infrastructure
```bash
docker-compose restart
```

### Arrêter l'infrastructure
```bash
docker-compose down
```

### Redémarrer un conteneur spécifique
```bash
docker-compose restart firewall
```

### Voir l'état des conteneurs
```bash
docker-compose ps
```

### Mettre à jour les règles UFW
```bash
ansible-playbook ansible/playbooks/rules_update.yml
```

---

## ❌ Résolution de problèmes

### Problème 1 : "Permission denied" avec Docker

**Solution :**
```bash
# Ajouter votre utilisateur au groupe docker
sudo usermod -aG docker $USER

# Se déconnecter et reconnecter, ou :
newgrp docker

# Réessayer
docker ps
```

### Problème 2 : Ansible ne trouve pas les fichiers

**Solution :**
Assurez-vous d'être dans le bon répertoire :
```bash
cd "SAE502 final"
pwd  # Doit afficher le chemin avec "SAE502 final"
ls   # Doit afficher ansible/, containers/, docker-compose.yml, etc.
```

### Problème 3 : Les conteneurs ne démarrent pas

**Solution :**
```bash
# Voir les erreurs
docker-compose logs

# Reconstruire les images
docker-compose build --no-cache

# Redémarrer
docker-compose up -d
```

### Problème 4 : Le port 5000 est déjà utilisé

**Solution :**
Modifiez `docker-compose.yml` et changez :
```yaml
ports:
  - "5000:5000"  # Changez 5000 par un autre port, ex: "8080:5000"
```

Puis redéployez :
```bash
ansible-playbook ansible/playbooks/deploy.yml
```

### Problème 5 : UFW ne fonctionne pas dans le conteneur

**Solution :**
Le conteneur firewall a besoin de privilèges. Vérifiez dans `docker-compose.yml` :
```yaml
cap_add:
  - NET_ADMIN
  - NET_RAW
privileged: true
```

---

## 📝 Résumé des commandes essentielles

```bash
# 1. Installer Docker
ansible-playbook ansible/playbooks/install.yml

# 2. Déployer tout
ansible-playbook ansible/playbooks/deploy.yml

# 3. Accéder à la supervision
# Ouvrir http://localhost:5000

# 4. Tester
ansible-playbook ansible/playbooks/tests.yml

# 5. Voir les logs
docker-compose logs -f
```

---

## 🎓 Comprendre ce qui se passe

1. **install.yml** → Installe Docker sur votre machine
2. **deploy.yml** → 
   - Construit 4 images Docker (pare-feu, collecteur, supervision, client)
   - Lance les 4 conteneurs
   - Configure le pare-feu avec les règles
3. **Le pare-feu** → Filtre le trafic et génère des logs
4. **Le collecteur** → Reçoit les logs et les stocke
5. **La supervision** → Lit les logs et les affiche sur le web
6. **Le client** → Permet de tester le pare-feu

---

## ✅ Checklist de vérification

- [ ] Ansible installé (`ansible --version`)
- [ ] Docker installé (`docker --version`)
- [ ] Projet copié sur la machine Linux
- [ ] `install.yml` exécuté avec succès
- [ ] `deploy.yml` exécuté avec succès
- [ ] 4 conteneurs en cours d'exécution (`docker ps`)
- [ ] Supervision accessible sur http://localhost:5000
- [ ] Tests fonctionnent (`tests.yml`)

Si toutes les cases sont cochées, votre projet est opérationnel ! 🎉

---

## 💡 Besoin d'aide ?

Si vous rencontrez un problème :
1. Vérifiez les logs : `docker-compose logs`
2. Vérifiez l'état : `docker-compose ps`
3. Relisez la section "Résolution de problèmes" ci-dessus
4. Vérifiez que vous êtes dans le bon répertoire



