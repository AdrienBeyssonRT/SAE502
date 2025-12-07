# 🔍 Diagnostic Complet - Problème des logs

## ❌ Problèmes identifiés

1. **Seulement 4 logs anciens s'affichent** - Les nouveaux logs ne sont pas parsés
2. **Pas d'IP source ni de statistiques** - Le parsing ne fonctionne pas correctement
3. **Le pare-feu ne bloque rien** - Les règles ne sont peut-être pas appliquées
4. **Les tests nmap ne génèrent pas de logs** - Les logs UFW ne sont pas générés

## 🔧 Corrections appliquées

### 1. Configuration rsyslog du firewall
- ✅ Ajout de `imfile` pour lire `/var/log/kern.log` en continu
- ✅ Lecture automatique des nouveaux logs UFW
- ✅ Envoi de tous les logs kernel vers le logcollector

### 2. Parsing amélioré
- ✅ Détection de plusieurs formats d'IP (SRC=, SRC:, from)
- ✅ Détection de plusieurs formats de ports (DPT=, DPT:, port)
- ✅ Détection automatique des protocoles (TCP, UDP, ICMP)
- ✅ Meilleure extraction des informations réseau

### 3. Script de test
- ✅ Création d'un script pour forcer la génération de logs

## 🔄 Pour appliquer les corrections

```bash
# Arrêter les conteneurs
docker-compose down

# Reconstruire avec toutes les corrections
docker-compose build --no-cache firewall supervision

# Redémarrer
docker-compose up -d

# Attendre que tout soit prêt
sleep 10
```

## 🧪 Tests à effectuer

### 1. Vérifier que UFW génère des logs

```bash
# Dans le firewall, vérifier les logs kernel
docker exec firewall tail -f /var/log/kern.log | grep UFW
```

Dans un autre terminal, générer du trafic :
```bash
docker exec client nmap -p 445 firewall
```

Vous devriez voir des logs apparaître dans le premier terminal.

### 2. Vérifier que les logs sont envoyés

```bash
# Vérifier les logs dans le logcollector
docker exec logcollector tail -f /var/log/firewall/firewall_*.log | grep UFW
```

### 3. Vérifier l'API de debug

Ouvrez : http://localhost:5000/api/debug

Cela vous dira :
- Combien de lignes sont lues
- Combien de logs sont parsés
- Des exemples de logs parsés

### 4. Générer du trafic depuis l'extérieur du réseau interne

Le problème peut être que le client est sur le réseau interne (172.20.0.0/16), donc :
- SSH est autorisé → pas de log BLOCK
- Pour voir des logs BLOCK, il faut tester depuis l'extérieur

**Solution : Tester depuis la machine hôte**

```bash
# Depuis la machine Linux (pas depuis le conteneur client)
nmap -p 445 $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' firewall)
```

Ou créer un conteneur sur un autre réseau :

```bash
# Créer un conteneur de test sur un autre réseau
docker run --rm --network tests_network -it ubuntu:22.04 bash
# Dans ce conteneur
apt update && apt install -y nmap
nmap -p 445 firewall
```

## 🔍 Diagnostic étape par étape

### Étape 1 : Vérifier que UFW fonctionne

```bash
docker exec firewall ufw status verbose
```

### Étape 2 : Vérifier que les logs sont générés

```bash
# Générer du trafic
docker exec client nmap -p 445 firewall

# Vérifier les logs dans le firewall
docker exec firewall tail -20 /var/log/kern.log | grep -i ufw
```

### Étape 3 : Vérifier que rsyslog envoie les logs

```bash
# Vérifier que rsyslog fonctionne
docker exec firewall ps aux | grep rsyslog

# Tester l'envoi manuel
docker exec firewall logger -n logcollector -P 514 -d "Test manuel"

# Vérifier dans le logcollector (attendre 2 secondes)
docker exec logcollector tail -5 /var/log/firewall/firewall_*.log
```

### Étape 4 : Vérifier le parsing

Ouvrez : http://localhost:5000/api/debug

Regardez :
- `total_lines` : nombre de lignes dans les fichiers
- `parsed_count` : nombre de logs parsés
- `parsed_samples` : exemples de logs parsés

Si `parsed_count` est très faible par rapport à `total_lines`, le parsing ne fonctionne pas.

## 📝 Notes importantes

1. **Les logs UFW ne sont générés que pour le trafic entrant**
   - Trafic bloqué → logs `[UFW BLOCK]`
   - Trafic autorisé → peut générer des logs `[UFW ALLOW]`
   - Pas de trafic = pas de logs

2. **Le client est sur le réseau interne (172.20.0.0/16)**
   - SSH depuis le client est autorisé → pas de log BLOCK
   - Pour voir des logs BLOCK, tester des ports bloqués (445, 3389) depuis l'extérieur

3. **Les logs sont écrits dans `/var/log/kern.log`**
   - UFW utilise le kernel logging
   - rsyslog doit lire ce fichier et l'envoyer au logcollector

4. **Le parsing doit détecter les logs même sans "UFW" explicite**
   - Les logs kernel peuvent contenir des infos réseau
   - Le parsing doit être assez permissif

## 🎯 Solution complète

Après reconstruction, testez dans cet ordre :

1. Vérifier que les logs sont générés dans le firewall
2. Vérifier que les logs sont envoyés au logcollector
3. Vérifier que les logs sont parsés dans la supervision
4. Générer du trafic depuis l'extérieur pour voir des logs BLOCK

