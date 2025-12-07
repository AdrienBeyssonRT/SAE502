# 🔥 Comment générer des logs UFW

## ❌ Problème

Les scans `nmap` ne génèrent **PAS** toujours de logs UFW car :
- `nmap` envoie des paquets de scan, pas de vraies connexions TCP
- UFW ne génère des logs que pour les **vraies connexions** qui déclenchent les règles
- Les ports "closed" ou "filtered" ne génèrent pas toujours de logs

## ✅ Solution : Créer de vraies connexions TCP

### Méthode 1 : Utiliser le script automatique

```bash
# Depuis le conteneur client
docker exec client bash /usr/local/bin/generate-traffic.sh
```

Ce script crée de vraies connexions TCP qui déclencheront des logs UFW.

### Méthode 2 : Commandes manuelles

```bash
# Entrer dans le conteneur client
docker exec -it client bash

# Test 1 : Connexion TCP sur port 445 (SMB - BLOQUÉ)
timeout 2 bash -c '</dev/tcp/firewall/445' 2>&1 || true

# Test 2 : Connexion TCP sur port 3389 (RDP - BLOQUÉ)
timeout 2 bash -c '</dev/tcp/firewall/3389' 2>&1 || true

# Test 3 : Avec netcat (plus visible)
nc -zv -w 2 firewall 445
nc -zv -w 2 firewall 3389

# Test 4 : Avec telnet
telnet firewall 445
# (Appuyez sur Ctrl+C après quelques secondes)

# Sortir
exit
```

### Méthode 3 : Depuis le conteneur attacker (recommandé)

```bash
# Entrer dans le conteneur attacker (sur un autre réseau)
docker exec -it attacker bash

# Installer les outils si nécessaire
apt update && apt install -y netcat-openbsd

# Générer du trafic bloqué
nc -zv -w 2 firewall 445
nc -zv -w 2 firewall 3389
timeout 2 bash -c '</dev/tcp/firewall/445' 2>&1 || true

# Sortir
exit
```

## 🔍 Vérifier que les logs sont générés

### Étape 1 : Vérifier dans le firewall

```bash
# Voir les logs UFW en temps réel
docker exec firewall tail -f /var/log/kern.log | grep -i ufw
```

Dans un autre terminal, générez du trafic. Vous devriez voir des logs apparaître.

### Étape 2 : Vérifier dans le logcollector

```bash
# Attendre 3-5 secondes après le test
sleep 5

# Voir les logs reçus
docker exec logcollector tail -20 /var/log/firewall/firewall_*.log | grep -i ufw
```

### Étape 3 : Vérifier dans l'interface web

1. Ouvrez http://localhost:5000
2. Rafraîchissez la page
3. Vous devriez voir les nouveaux logs avec :
   - IP source
   - Port destination
   - Action (BLOCK, ALLOW, etc.)

## 📝 Format des logs UFW attendus

Les logs UFW dans `/var/log/kern.log` ressemblent à :

```
Dec  7 10:36:15 firewall kernel: [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=172.20.0.2 DST=172.20.0.3 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=12345 DF PROTO=TCP SPT=54321 DPT=445 WINDOW=29200 RES=0x00 SYN URGP=0
```

## 🚨 Si aucun log n'apparaît

### Vérification 1 : UFW est-il actif ?

```bash
docker exec firewall ufw status verbose
```

Vous devriez voir :
- `Status: active`
- `Logging: on (high)`

### Vérification 2 : Les logs sont-ils générés ?

```bash
# Générer du trafic
docker exec client nc -zv -w 2 firewall 445

# Vérifier immédiatement (dans les 2 secondes)
docker exec firewall tail -10 /var/log/kern.log | grep -i ufw
```

Si vous ne voyez rien, UFW ne génère pas de logs. Vérifiez :
- Le niveau de logging : `docker exec firewall ufw status verbose | grep Logging`
- Les règles UFW : `docker exec firewall ufw status numbered`

### Vérification 3 : rsyslog envoie-t-il les logs ?

```bash
# Tester l'envoi manuel
docker exec firewall logger -n logcollector -P 514 -d "Test manuel"

# Attendre 2 secondes
sleep 2

# Vérifier dans le logcollector
docker exec logcollector tail -5 /var/log/firewall/firewall_*.log | grep "Test manuel"
```

Si le test manuel fonctionne mais pas les logs UFW, le problème est dans la configuration rsyslog.

### Vérification 4 : Le parsing fonctionne-t-il ?

Ouvrez : http://localhost:5000/api/debug

Regardez :
- `total_lines` : nombre de lignes dans les fichiers
- `parsed_count` : nombre de logs parsés
- `parsed_samples` : exemples de logs parsés

Si `parsed_count` est faible, le parsing ne fonctionne pas correctement.

## 🎯 Test complet recommandé

```bash
# 1. Générer du trafic depuis attacker
docker exec attacker bash -c "apt update && apt install -y netcat-openbsd && nc -zv -w 2 firewall 445"

# 2. Vérifier dans le firewall (dans les 2 secondes)
docker exec firewall tail -10 /var/log/kern.log | grep -i ufw

# 3. Attendre 5 secondes
sleep 5

# 4. Vérifier dans le logcollector
docker exec logcollector tail -10 /var/log/firewall/firewall_*.log | grep -i ufw

# 5. Vérifier l'API debug
# Ouvrez http://localhost:5000/api/debug dans votre navigateur

# 6. Rafraîchir l'interface web
# Ouvrez http://localhost:5000 et rafraîchissez
```

## 💡 Astuce

Pour générer beaucoup de logs rapidement :

```bash
# Depuis le conteneur client ou attacker
for port in 445 3389 139 137 138; do
    echo "Test port $port..."
    timeout 1 bash -c "</dev/tcp/firewall/$port" 2>&1 || true
    sleep 1
done
```

Cela génère des connexions sur plusieurs ports bloqués et devrait créer plusieurs logs UFW.

