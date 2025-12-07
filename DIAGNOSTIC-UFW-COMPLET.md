# 🔍 Diagnostic Complet - Logs UFW absents

## ❌ Problème identifié

D'après le debug, les logs parsés sont des **logs de bridge Docker** (br-e98a78eff924: port 2(veth58b5f6c)) et **PAS des logs UFW**.

Les logs UFW ne sont **PAS présents** dans les fichiers de logs.

## 🔍 Diagnostic étape par étape

### Étape 1 : Vérifier que UFW génère des logs

```bash
# Entrer dans le firewall
docker exec -it firewall bash

# Vérifier le statut UFW
ufw status verbose

# Vérifier le niveau de logging (doit être "on (high)")
ufw status verbose | grep Logging

# Générer du trafic depuis un autre terminal
# (depuis client ou attacker)
docker exec client nc -zv -w 2 firewall 445

# Vérifier IMMÉDIATEMENT (dans les 2 secondes) dans le firewall
tail -20 /var/log/kern.log | grep -i ufw
```

**Si vous ne voyez RIEN**, UFW ne génère pas de logs. Causes possibles :
- UFW n'est pas activé
- Le logging n'est pas activé
- Les règles ne sont pas correctement configurées

### Étape 2 : Vérifier que rsyslog envoie les logs

```bash
# Dans le firewall
docker exec firewall bash -c "tail -10 /var/log/kern.log | grep UFW"

# Si vous voyez des logs UFW, tester l'envoi
docker exec firewall logger -n logcollector -P 514 -d "TEST UFW - $(date)"

# Attendre 3 secondes
sleep 3

# Vérifier dans le logcollector
docker exec logcollector tail -10 /var/log/firewall/firewall_*.log | grep "TEST UFW"
```

**Si le test manuel fonctionne mais pas les logs UFW**, le problème est dans la configuration rsyslog.

### Étape 3 : Vérifier la configuration rsyslog

```bash
# Vérifier la configuration rsyslog du firewall
docker exec firewall cat /etc/rsyslog.conf

# Vérifier que rsyslog fonctionne
docker exec firewall ps aux | grep rsyslog

# Vérifier les logs rsyslog
docker exec firewall tail -20 /var/log/messages | grep rsyslog
```

### Étape 4 : Forcer la génération de logs UFW

Le problème peut être que UFW ne génère des logs que pour certaines connexions. Testez :

```bash
# Depuis le conteneur attacker (sur un autre réseau)
docker exec attacker bash -c "apt update && apt install -y netcat-openbsd"

# Générer plusieurs tentatives de connexion
for i in {1..5}; do
    echo "Tentative $i..."
    timeout 1 bash -c "</dev/tcp/firewall/445" 2>&1 || true
    sleep 1
done

# Vérifier IMMÉDIATEMENT dans le firewall
docker exec firewall tail -30 /var/log/kern.log | grep -i ufw
```

## 🔧 Solutions possibles

### Solution 1 : Vérifier que UFW est bien configuré

```bash
# Dans le firewall
docker exec firewall bash

# Vérifier le statut
ufw status verbose

# Si le logging n'est pas "on (high)", le réactiver
ufw logging high

# Vérifier les règles
ufw status numbered

# Tester une règle
ufw deny 9999/tcp comment 'Test'
ufw delete deny 9999/tcp
```

### Solution 2 : Vérifier que les logs sont écrits dans kern.log

```bash
# Dans le firewall, surveiller kern.log en temps réel
docker exec firewall tail -f /var/log/kern.log

# Dans un autre terminal, générer du trafic
docker exec attacker nc -zv -w 2 firewall 445
```

Si vous ne voyez **RIEN** dans kern.log, le problème est que UFW ne génère pas de logs.

### Solution 3 : Vérifier la configuration du kernel logging

UFW utilise le kernel logging. Vérifiez :

```bash
# Dans le firewall
docker exec firewall bash

# Vérifier que le kernel logging est activé
dmesg | grep -i ufw | tail -10

# Vérifier les paramètres sysctl
sysctl net.netfilter.nf_log_all_netns
```

### Solution 4 : Forcer la génération de logs avec iptables

Si UFW ne génère pas de logs, on peut vérifier directement iptables :

```bash
# Dans le firewall
docker exec firewall bash

# Vérifier les règles iptables générées par UFW
iptables -L -n -v | grep -i ufw

# Vérifier les règles de logging
iptables -L -n -v | grep -i log
```

## 🎯 Test complet recommandé

```bash
# 1. Vérifier UFW dans le firewall
docker exec firewall ufw status verbose

# 2. Générer du trafic depuis attacker
docker exec attacker bash -c "apt update && apt install -y netcat-openbsd && for i in {1..3}; do timeout 1 bash -c '</dev/tcp/firewall/445' 2>&1 || true; sleep 1; done"

# 3. Vérifier IMMÉDIATEMENT dans le firewall (dans les 2 secondes)
docker exec firewall tail -30 /var/log/kern.log | grep -i ufw

# 4. Si vous voyez des logs UFW, vérifier qu'ils sont envoyés
docker exec firewall logger -n logcollector -P 514 -d "Test après UFW"

# 5. Attendre 5 secondes
sleep 5

# 6. Vérifier dans le logcollector
docker exec logcollector tail -20 /var/log/firewall/firewall_*.log | grep -E "(UFW|Test après)"

# 7. Vérifier l'API debug
# Ouvrez http://localhost:5000/api/debug
```

## 🚨 Si aucun log UFW n'apparaît dans kern.log

Cela signifie que **UFW ne génère pas de logs**. Causes possibles :

1. **UFW n'est pas activé** : `ufw status` doit montrer "Status: active"
2. **Le logging n'est pas activé** : `ufw status verbose | grep Logging` doit montrer "Logging: on (high)"
3. **Les règles ne déclenchent pas de logs** : Les règles "deny" doivent générer des logs
4. **Le kernel logging n'est pas configuré** : UFW utilise le kernel logging

**Solution** : Réinitialiser UFW et le reconfigurer

```bash
# Dans le firewall
docker exec firewall bash

# Réinitialiser UFW
ufw --force reset

# Reconfigurer
ufw default deny incoming
ufw default allow outgoing
ufw logging high
ufw deny 445/tcp comment 'Blocage SMB'
ufw deny 3389/tcp comment 'Blocage RDP'
ufw --force enable

# Vérifier
ufw status verbose

# Tester
# (depuis un autre terminal)
docker exec attacker nc -zv -w 2 firewall 445

# Vérifier IMMÉDIATEMENT
tail -20 /var/log/kern.log | grep -i ufw
```

## 📝 Format attendu des logs UFW

Les logs UFW dans `/var/log/kern.log` doivent ressembler à :

```
Dec  7 10:36:15 firewall kernel: [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=172.23.0.2 DST=172.20.0.3 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=12345 DF PROTO=TCP SPT=54321 DPT=445 WINDOW=29200 RES=0x00 SYN URGP=0
```

Si vous ne voyez **PAS** ce format dans `/var/log/kern.log`, UFW ne génère pas de logs.

