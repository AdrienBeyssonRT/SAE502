# 🔧 Correction du système de logs

## ❌ Problème identifié

L'interface de supervision ne montre aucun log, même après des tests avec nmap.

## 🔍 Causes possibles

1. **Les logs UFW ne sont pas envoyés au logcollector**
   - UFW écrit dans `/var/log/kern.log` via le kernel
   - rsyslog doit capturer ces logs et les envoyer

2. **Le logcollector ne reçoit pas les logs**
   - Problème de réseau entre firewall et logcollector
   - Configuration rsyslog incorrecte

3. **L'application de supervision ne lit pas les logs**
   - Chemin incorrect vers les logs
   - Format de logs non reconnu

## ✅ Corrections appliquées

### 1. Configuration rsyslog du firewall
- ✅ Ajout du module `imklog` pour capturer les logs kernel
- ✅ Ajout du module `imfile` pour lire `/var/log/ufw.log`
- ✅ Envoi spécifique des logs kernel et UFW vers le logcollector
- ✅ Création des fichiers de logs dans le Dockerfile

### 2. Application de supervision
- ✅ Amélioration du parsing des logs UFW
- ✅ Meilleure détection des différents formats de logs
- ✅ Ajout d'une API de debug (`/api/debug`)
- ✅ Messages de debug pour identifier les problèmes

### 3. Script entrypoint du firewall
- ✅ Création des fichiers de logs au démarrage

## 🔄 Pour appliquer les corrections

```bash
# Arrêter les conteneurs
docker-compose down

# Reconstruire les images
docker-compose build --no-cache firewall supervision

# Redémarrer
docker-compose up -d

# Vérifier les logs
docker-compose logs -f firewall
docker-compose logs -f logcollector
```

## 🧪 Tests à effectuer

### 1. Générer du trafic depuis le client

```bash
# Entrer dans le conteneur client
docker exec -it client bash

# Tester des connexions qui seront bloquées
nmap -p 445 firewall
nc -zv firewall 445
curl http://firewall:80

# Tester des connexions autorisées
ping -c 3 firewall
```

### 2. Vérifier les logs dans le firewall

```bash
# Voir les logs UFW
docker exec firewall tail -f /var/log/ufw.log

# Voir les logs kernel
docker exec firewall tail -f /var/log/kern.log
```

### 3. Vérifier les logs dans le logcollector

```bash
# Voir les logs reçus
docker exec logcollector ls -la /var/log/firewall/
docker exec logcollector tail -f /var/log/firewall/*.log
```

### 4. Vérifier l'API de debug

Ouvrir dans le navigateur : http://localhost:5000/api/debug

Cela affichera :
- Si le répertoire de logs existe
- Quels fichiers de logs sont présents
- Un échantillon des logs

## 🔍 Diagnostic

Si les logs n'apparaissent toujours pas :

1. **Vérifier que rsyslog fonctionne dans le firewall**
   ```bash
   docker exec firewall ps aux | grep rsyslog
   ```

2. **Vérifier la connectivité réseau**
   ```bash
   docker exec firewall ping -c 3 logcollector
   ```

3. **Vérifier que le logcollector écoute**
   ```bash
   docker exec logcollector netstat -ulnp | grep 514
   ```

4. **Tester l'envoi manuel de logs**
   ```bash
   docker exec firewall logger -n logcollector -P 514 "Test log"
   ```

5. **Vérifier les logs du logcollector**
   ```bash
   docker logs logcollector | tail -20
   ```

## 📝 Notes importantes

- Les logs UFW sont générés uniquement quand il y a du trafic qui déclenche les règles
- Les connexions depuis le réseau interne (172.20.0.0/16) vers le port 22 sont autorisées, donc pas de log BLOCK
- Pour voir des logs BLOCK, tester des ports bloqués (445, 3389, etc.) depuis l'extérieur du réseau interne

