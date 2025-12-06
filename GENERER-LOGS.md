# 🔍 Guide pour générer et voir les logs

## ❌ Problème actuel

Les logs ne sont pas créés dans `/var/log/firewall/` car :
1. **Les logs UFW ne sont générés que quand il y a du trafic qui déclenche les règles**
2. Il faut générer du trafic depuis le client vers le firewall

## ✅ Solution : Générer du trafic de test

### Étape 1 : Reconstruire les conteneurs avec les corrections

```bash
# Arrêter
docker-compose down

# Reconstruire
docker-compose build --no-cache firewall logcollector

# Redémarrer
docker-compose up -d
```

### Étape 2 : Générer du trafic depuis le client

```bash
# Entrer dans le conteneur client
docker exec -it client bash

# Tester des connexions qui seront BLOQUÉES (génère des logs BLOCK)
nmap -p 445 firewall
nc -zv firewall 445
nc -zv firewall 3389
curl http://firewall:80

# Tester des connexions qui seront AUTORISÉES (génère des logs ALLOW)
ping -c 3 firewall

# Sortir
exit
```

### Étape 3 : Vérifier les logs

```bash
# Vérifier les logs dans le firewall
docker exec firewall tail -20 /var/log/kern.log

# Vérifier les logs dans le logcollector
docker exec logcollector ls -la /var/log/firewall/
docker exec logcollector cat /var/log/firewall/*.log | tail -20

# Vérifier l'API de debug
curl http://localhost:5000/api/debug
```

## 🔧 Script de test automatique

J'ai créé un script `TEST-LOGS.sh` que vous pouvez exécuter :

```bash
chmod +x TEST-LOGS.sh
./TEST-LOGS.sh
```

## 📝 Notes importantes

1. **Les logs UFW ne sont générés que pour le trafic entrant**
   - Les connexions sortantes depuis le firewall ne génèrent pas de logs UFW
   - Seul le trafic entrant (incoming) génère des logs

2. **Le client est sur le réseau 172.20.0.0/16**
   - Les connexions SSH depuis le client vers le firewall sont AUTORISÉES
   - Donc pas de log BLOCK pour SSH depuis le client
   - Pour voir des logs BLOCK, tester des ports bloqués (445, 3389, etc.)

3. **Les logs apparaissent dans `/var/log/kern.log`**
   - UFW écrit ses logs dans le kernel log
   - rsyslog lit ce fichier et l'envoie au logcollector

## 🐛 Si les logs n'apparaissent toujours pas

1. **Vérifier que rsyslog fonctionne dans le firewall**
   ```bash
   docker exec firewall ps aux | grep rsyslog
   docker exec firewall logger "Test log"
   ```

2. **Vérifier la connectivité réseau**
   ```bash
   docker exec firewall ping -c 3 logcollector
   docker exec firewall nc -zv logcollector 514
   ```

3. **Vérifier que le logcollector écoute**
   ```bash
   docker exec logcollector netstat -ulnp | grep 514
   ```

4. **Tester l'envoi manuel**
   ```bash
   docker exec firewall logger -n logcollector -P 514 -d "Test manuel"
   docker exec logcollector tail -f /var/log/firewall/*.log
   ```

5. **Vérifier les logs rsyslog**
   ```bash
   docker logs firewall | grep rsyslog
   docker logs logcollector
   ```

