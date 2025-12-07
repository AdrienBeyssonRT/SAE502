#!/usr/bin/env python3
"""
Application de supervision des logs du pare-feu
Affiche les logs en temps réel avec analyse visuelle
"""

from flask import Flask, render_template, jsonify, request
import os
import glob
import re
from datetime import datetime
from collections import defaultdict
import json

app = Flask(__name__)

# Chemin vers les logs du firewall (monté depuis logcollector)
LOG_DIR = "/mnt/logs/firewall"

def parse_log_line(line):
    """Parse une ligne de log UFW"""
    if not line.strip():
        return None
    
    # Ignorer les logs rsyslog internes et les logs de bridge Docker
    if any(keyword in line for keyword in [
        'rsyslogd:', 'imjournal:', 'imuxsock:', 'environment variable', 'TZ is not set',
        'entered blocking state', 'entered disabled state', 'entered forwarding state',
        'br-', 'veth', 'port 2(', 'port 3(', 'port 4('
    ]):
        return None
    
    # PRIORITÉ : Chercher spécifiquement les logs UFW
    # Les logs UFW contiennent toujours "[UFW" ou "UFW BLOCK" ou "UFW ALLOW"
    has_ufw = 'UFW' in line_upper and ('BLOCK' in line_upper or 'ALLOW' in line_upper or 'LIMIT' in line_upper or '[' in line)
    
    # Accepter toutes les lignes qui contiennent des informations réseau
    # Les logs kernel peuvent contenir des infos réseau même sans "UFW"
    has_network_info = any(keyword in line_upper for keyword in [
        'SRC=', 'DST=', 'DPT=', 'SPT=', 'PROTO=', 'BLOCK', 'ALLOW', 
        'IN=', 'OUT=', 'TCP', 'UDP', 'ICMP', 'SYN', 'ACK', 'FIN', 'RST',
        'LEN=', 'TTL=', 'ID=', 'WINDOW=', 'MAC='
    ])
    
    # Si c'est un log UFW, toujours l'accepter
    if has_ufw:
        pass  # Continuer le parsing
    elif not has_network_info:
        return None
    
    # Format typique: Dec  6 18:30:15 firewall kernel: [UFW BLOCK] IN=eth0 OUT= MAC=... SRC=192.168.1.100 DST=192.168.1.1 LEN=60 TOS=0x00 PREC=0x00 TTL=64 ID=12345 DF PROTO=TCP SPT=12345 DPT=22 WINDOW=29200 RES=0x00 SYN URGP=0
    log_entry = {
        'timestamp': None,
        'action': None,
        'src_ip': None,
        'dst_ip': None,
        'protocol': None,
        'sport': None,
        'dport': None,
        'raw': line
    }
    
    # Extraire l'action UFW (plusieurs formats possibles)
    line_upper = line.upper()
    
    # Détecter les actions UFW explicites
    if '[UFW BLOCK]' in line or 'UFW BLOCK' in line_upper:
        log_entry['action'] = 'BLOCK'
    elif '[UFW ALLOW]' in line or 'UFW ALLOW' in line_upper:
        log_entry['action'] = 'ALLOW'
    elif '[UFW LIMIT]' in line or 'UFW LIMIT' in line_upper:
        log_entry['action'] = 'LIMIT'
    # Si pas d'action UFW explicite mais présence de mots-clés réseau, essayer de deviner
    elif 'SRC=' in line and 'DST=' in line:
        # C'est probablement un log réseau, essayer de déterminer l'action
        if 'BLOCK' in line_upper or 'DENY' in line_upper:
            log_entry['action'] = 'BLOCK'
        elif 'ALLOW' in line_upper or 'ACCEPT' in line_upper:
            log_entry['action'] = 'ALLOW'
        elif 'LIMIT' in line_upper:
            log_entry['action'] = 'LIMIT'
        else:
            # Log réseau sans action claire - probablement un log kernel
            log_entry['action'] = 'NETWORK'
    
    # Extraire IP source (plusieurs formats possibles)
    src_match = re.search(r'SRC[=:](\d+\.\d+\.\d+\.\d+)', line)
    if not src_match:
        # Essayer autre format
        src_match = re.search(r'from\s+(\d+\.\d+\.\d+\.\d+)', line, re.IGNORECASE)
    if src_match:
        log_entry['src_ip'] = src_match.group(1)
    
    # Extraire IP destination (plusieurs formats possibles)
    dst_match = re.search(r'DST[=:](\d+\.\d+\.\d+\.\d+)', line)
    if not dst_match:
        # Essayer autre format
        dst_match = re.search(r'to\s+(\d+\.\d+\.\d+\.\d+)', line, re.IGNORECASE)
    if dst_match:
        log_entry['dst_ip'] = dst_match.group(1)
    
    # Extraire protocole
    proto_match = re.search(r'PROTO[=:](\w+)', line)
    if not proto_match:
        # Essayer de détecter dans la ligne
        if 'TCP' in line_upper and 'PROTO' not in line_upper:
            log_entry['protocol'] = 'TCP'
        elif 'UDP' in line_upper and 'PROTO' not in line_upper:
            log_entry['protocol'] = 'UDP'
        elif 'ICMP' in line_upper:
            log_entry['protocol'] = 'ICMP'
    elif proto_match:
        log_entry['protocol'] = proto_match.group(1)
    
    # Extraire port source
    sport_match = re.search(r'SPT[=:](\d+)', line)
    if sport_match:
        log_entry['sport'] = sport_match.group(1)
    
    # Extraire port destination (plusieurs formats)
    dport_match = re.search(r'DPT[=:](\d+)', line)
    if not dport_match:
        # Essayer autre format
        dport_match = re.search(r'port\s+(\d+)', line, re.IGNORECASE)
    if dport_match:
        log_entry['dport'] = dport_match.group(1)
    
    # Extraire timestamp (format syslog) - plusieurs formats possibles
    time_match = re.search(r'(\w+\s+\d+\s+\d+:\d+:\d+)', line)
    if not time_match:
        # Essayer autre format
        time_match = re.search(r'(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})', line)
    if time_match:
        try:
            log_entry['timestamp'] = time_match.group(1)
        except:
            pass
    
    # Si on a au moins une IP source ou un port destination, c'est un log réseau valide
    if log_entry['src_ip'] or log_entry['dport']:
        # Si pas d'action détectée mais qu'on a des infos réseau, marquer comme NETWORK
        if not log_entry['action']:
            log_entry['action'] = 'NETWORK'
        return log_entry
    
    # Si on a un protocole et une action, c'est aussi valide
    if log_entry['protocol'] and log_entry['action']:
        return log_entry
    
    # Si on a au moins SRC= ou DST= dans la ligne, c'est un log réseau (même si pas parsé)
    if 'SRC=' in line or 'DST=' in line or 'SRC:' in line or 'DST:' in line:
        if not log_entry['action']:
            log_entry['action'] = 'NETWORK'
        # Essayer d'extraire au moins l'IP source avec des regex très permissives
        if not log_entry['src_ip']:
            # Essayer plusieurs patterns
            for pattern in [
                r'SRC[=:](\d+\.\d+\.\d+\.\d+)',
                r'FROM\s+(\d+\.\d+\.\d+\.\d+)',
                r'(\d+\.\d+\.\d+\.\d+).*SRC',
                r'SRC.*?(\d+\.\d+\.\d+\.\d+)'
            ]:
                src_alt = re.search(pattern, line, re.IGNORECASE)
                if src_alt:
                    log_entry['src_ip'] = src_alt.group(1)
                    break
        if not log_entry['dst_ip']:
            for pattern in [
                r'DST[=:](\d+\.\d+\.\d+\.\d+)',
                r'TO\s+(\d+\.\d+\.\d+\.\d+)',
                r'(\d+\.\d+\.\d+\.\d+).*DST',
                r'DST.*?(\d+\.\d+\.\d+\.\d+)'
            ]:
                dst_alt = re.search(pattern, line, re.IGNORECASE)
                if dst_alt:
                    log_entry['dst_ip'] = dst_alt.group(1)
                    break
        if not log_entry['dport']:
            for pattern in [
                r'DPT[=:](\d+)',
                r'PORT\s+(\d+)',
                r'\.(\d+)\s+.*DPT',
                r'DPT.*?(\d+)'
            ]:
                dport_alt = re.search(pattern, line, re.IGNORECASE)
                if dport_alt:
                    log_entry['dport'] = dport_alt.group(1)
                    break
        if log_entry['src_ip'] or log_entry['dport'] or log_entry['dst_ip']:
            return log_entry
    
    # Dernière tentative : si la ligne contient une IP et des mots-clés réseau, créer un log basique
    ip_match = re.search(r'(\d+\.\d+\.\d+\.\d+)', line)
    if ip_match and has_network_info:
        if not log_entry['action']:
            log_entry['action'] = 'NETWORK'
        if not log_entry['src_ip']:
            log_entry['src_ip'] = ip_match.group(1)
        return log_entry
    
    return None

def get_recent_logs(limit=1000):
    """Récupère les logs récents"""
    logs = []
    
    if not os.path.exists(LOG_DIR):
        print(f"LOG_DIR n'existe pas: {LOG_DIR}")
        return logs
    
    # Lire tous les fichiers de log
    log_files = glob.glob(os.path.join(LOG_DIR, "*.log"))
    if not log_files:
        print(f"Aucun fichier de log trouvé dans {LOG_DIR}")
        # Essayer de lister le contenu du répertoire
        try:
            dir_contents = os.listdir(LOG_DIR)
            print(f"Contenu de {LOG_DIR}: {dir_contents}")
        except:
            pass
        return logs
    
    log_files.sort(reverse=True)  # Plus récents en premier
    
    # Prioriser les fichiers firewall_*.log
    firewall_logs = [f for f in log_files if 'firewall_' in os.path.basename(f)]
    other_logs = [f for f in log_files if 'firewall_' not in os.path.basename(f)]
    log_files = firewall_logs + other_logs
    
    for log_file in log_files[:10]:  # Limiter aux 10 fichiers les plus récents
        try:
            with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                lines = f.readlines()
                print(f"Lecture de {log_file}: {len(lines)} lignes")
                parsed_count = 0
                for line in lines:
                    # Ignorer les logs rsyslog internes
                    if any(keyword in line for keyword in ['rsyslogd:', 'imjournal:', 'imuxsock:', 'environment variable', 'TZ is not set']):
                        continue
                    parsed = parse_log_line(line)
                    if parsed:
                        logs.append(parsed)
                        parsed_count += 1
                print(f"  -> {parsed_count} logs parsés depuis {os.path.basename(log_file)}")
        except Exception as e:
            print(f"Erreur lecture {log_file}: {e}")
    
    # Trier par timestamp (plus récent en premier)
    logs.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
    print(f"Total de {len(logs)} logs parsés")
    return logs[:limit]

def get_statistics():
    """Calcule les statistiques des logs"""
    logs = get_recent_logs(5000)
    
    stats = {
        'total': len(logs),
        'by_action': defaultdict(int),
        'by_src_ip': defaultdict(int),
        'by_dport': defaultdict(int),
        'by_protocol': defaultdict(int),
        'blocked_attempts': 0,
        'allowed_connections': 0
    }
    
    for log in logs:
        if log.get('action'):
            stats['by_action'][log['action']] += 1
            if log['action'] == 'BLOCK':
                stats['blocked_attempts'] += 1
            elif log['action'] == 'ALLOW':
                stats['allowed_connections'] += 1
            # Les logs NETWORK avec IP source sont probablement des événements bloqués
            elif log['action'] == 'NETWORK' and log.get('src_ip'):
                # Compter comme bloqué si on a une IP source (probablement un trafic entrant)
                stats['blocked_attempts'] += 1
        
        if log.get('src_ip'):
            stats['by_src_ip'][log['src_ip']] += 1
        
        if log.get('dport'):
            stats['by_dport'][log['dport']] += 1
        
        if log.get('protocol'):
            stats['by_protocol'][log['protocol']] += 1
    
    return stats

@app.route('/')
def index():
    """Page principale avec tableau de bord"""
    return render_template('dashboard.html')

@app.route('/api/logs')
def api_logs():
    """API pour récupérer les logs"""
    limit = int(request.args.get('limit', 100))
    logs = get_recent_logs(limit)
    return jsonify(logs)

@app.route('/api/stats')
def api_stats():
    """API pour récupérer les statistiques"""
    stats = get_statistics()
    # Convertir defaultdict en dict pour JSON
    return jsonify({
        'total': stats['total'],
        'by_action': dict(stats['by_action']),
        'by_src_ip': dict(stats['by_src_ip']),
        'by_dport': dict(stats['by_dport']),
        'by_protocol': dict(stats['by_protocol']),
        'blocked_attempts': stats['blocked_attempts'],
        'allowed_connections': stats['allowed_connections']
    })

@app.route('/api/recent')
def api_recent():
    """API pour les logs récents (dernières 50 lignes)"""
    logs = get_recent_logs(50)
    # Debug: afficher le nombre de logs trouvés
    print(f"Nombre de logs trouvés: {len(logs)}")
    return jsonify(logs)

@app.route('/api/debug')
def api_debug():
    """API de debug pour vérifier l'état"""
    debug_info = {
        'log_dir_exists': os.path.exists(LOG_DIR),
        'log_dir': LOG_DIR,
        'log_files': [],
        'sample_logs': [],
        'parsed_samples': [],
        'total_lines': 0,
        'parsed_count': 0
    }
    
    if os.path.exists(LOG_DIR):
        log_files = glob.glob(os.path.join(LOG_DIR, "*.log"))
        debug_info['log_files'] = [os.path.basename(f) for f in log_files[:5]]
        
        # Lire quelques lignes d'un fichier pour debug
        if log_files:
            try:
                with open(log_files[0], 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                    debug_info['total_lines'] = len(lines)
                    debug_info['sample_logs'] = lines[:10]
                    
                    # Essayer de parser les échantillons
                    parsed_count = 0
                    for line in lines[:50]:
                        parsed = parse_log_line(line)
                        if parsed:
                            parsed_count += 1
                            if len(debug_info['parsed_samples']) < 5:
                                debug_info['parsed_samples'].append(parsed)
                    debug_info['parsed_count'] = parsed_count
            except Exception as e:
                debug_info['error'] = str(e)
    
    return jsonify(debug_info)

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)

