#!/bin/bash
# Script unique pour tout faire : installation + déploiement + tests
# Usage: sudo ./deploy-all.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifier que le script est exécuté en root
if [ "$EUID" -ne 0 ]; then 
    print_error "Ce script doit être exécuté en tant que root (utilisez sudo)"
    exit 1
fi

print_info "=========================================="
print_info "  INSTALLATION ET DÉPLOIEMENT COMPLET"
print_info "  AutoDeploy Firewall"
print_info "=========================================="
echo ""

# ==========================================
# PARTIE 1 : INSTALLATION DES DÉPENDANCES
# ==========================================

print_info "Étape 1/3 : Installation des dépendances système..."
echo ""

# Détecter la distribution
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VER=$VERSION_ID
    print_info "Distribution détectée: $OS $VER"
else
    print_error "Impossible de détecter la distribution"
    exit 1
fi

# Vérifier que c'est une distribution Debian/Ubuntu
if [[ "$OS" != "ubuntu" && "$OS" != "debian" ]]; then
    print_warn "Ce script est conçu pour Ubuntu/Debian. Continuer quand même? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Mise à jour du système
print_info "Mise à jour du système..."
export DEBIAN_FRONTEND=noninteractive

# Nettoyer les sources apt problématiques (PPA Ansible pour versions non supportées)
if ls /etc/apt/sources.list.d/ansible-ubuntu-ansible-*.list 2>/dev/null | grep -q .; then
    print_info "Nettoyage des sources apt problématiques (PPA Ansible)..."
    rm -f /etc/apt/sources.list.d/ansible-ubuntu-ansible-*.list 2>/dev/null || true
    rm -f /etc/apt/sources.list.d/ansible-ubuntu-ansible-*.save 2>/dev/null || true
fi

# Mise à jour en ignorant les erreurs de dépôts non disponibles
print_info "Mise à jour des dépôts apt..."
set +e  # Désactiver l'arrêt sur erreur temporairement
apt-get update -qq 2>&1 | grep -v "questing Release" | grep -v "has no Release file" | grep -v "^E:" > /dev/null
UPDATE_STATUS=$?
set -e  # Réactiver l'arrêt sur erreur
if [ $UPDATE_STATUS -ne 0 ]; then
    print_warn "Certains dépôts peuvent être indisponibles, continuation..."
fi
apt-get upgrade -y -qq || true
apt-get install -y -qq software-properties-common || true
print_info "✅ Système mis à jour"
echo ""

# Installation de Python et pip
print_info "Installation de Python 3 et pip..."
if ! command -v python3 &> /dev/null; then
    apt-get install -y -qq python3 python3-pip python3-venv
    print_info "✅ Python3 installé"
else
    print_info "✅ Python3 déjà installé"
fi

if ! command -v pip3 &> /dev/null; then
    apt-get install -y -qq python3-pip
    print_info "✅ pip3 installé"
else
    print_info "✅ pip3 déjà installé"
fi

python3 -m pip install --upgrade pip --quiet 2>/dev/null || true
echo ""

# Installation d'Ansible
print_info "Installation d'Ansible..."
if command -v ansible-playbook &> /dev/null; then
    ANSIBLE_VERSION=$(ansible-playbook --version | head -n1)
    print_info "✅ Ansible déjà installé: $ANSIBLE_VERSION"
else
    ANSIBLE_INSTALLED=false
    
    # Essayer d'installer via apt (PPA) pour Ubuntu/Debian
    if [ "$OS" == "ubuntu" ] || [ "$OS" == "debian" ]; then
        # Installer les dépendances nécessaires
        apt-get install -y -qq gnupg2 software-properties-common 2>/dev/null || true
        
        # Essayer d'ajouter le PPA Ansible (peut échouer pour les versions récentes)
        if apt-add-repository --yes --update ppa:ansible/ansible 2>/dev/null; then
            print_info "PPA Ansible ajouté avec succès"
            # Mise à jour en ignorant les erreurs de dépôts
            set +e
            apt-get update -qq 2>&1 | grep -v "questing Release" | grep -v "has no Release file" | grep -v "^E:" > /dev/null
            set -e
            if apt-get install -y -qq ansible 2>/dev/null; then
                ANSIBLE_INSTALLED=true
                print_info "✅ Ansible installé via PPA"
            fi
        else
            print_warn "PPA Ansible non disponible pour cette version (normal pour Ubuntu 25.10+)"
            print_info "Installation d'Ansible via pip..."
        fi
    fi
    
    # Si l'installation via apt a échoué, utiliser pip
    if [ "$ANSIBLE_INSTALLED" = false ]; then
        print_info "Installation d'Ansible via pip..."
        # Installer les dépendances système nécessaires pour Ansible
        apt-get install -y -qq python3-dev libffi-dev gcc 2>/dev/null || true
        
        if python3 -m pip install --upgrade pip setuptools wheel --quiet 2>/dev/null && \
           python3 -m pip install ansible --break-system-packages --quiet 2>/dev/null; then
            ANSIBLE_INSTALLED=true
            print_info "✅ Ansible installé via pip"
        fi
    fi
    
    # Vérification finale
    if command -v ansible-playbook &> /dev/null; then
        ANSIBLE_VERSION=$(ansible-playbook --version | head -n1)
        print_info "✅ Ansible installé avec succès: $ANSIBLE_VERSION"
    else
        print_error "❌ Échec de l'installation d'Ansible"
        print_error "Essayez manuellement: python3 -m pip install ansible --break-system-packages"
        exit 1
    fi
fi
echo ""

# Installation de Docker
print_info "Installation de Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_info "✅ Docker déjà installé: $DOCKER_VERSION"
else
    print_info "Installation de Docker..."
    
    apt-get install -y -qq \
        ca-certificates \
        curl \
        gnupg \
        lsb-release
    
    if [ ! -f /etc/apt/keyrings/docker.gpg ]; then
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        chmod a+r /etc/apt/keyrings/docker.gpg
    fi
    
    if [ ! -f /etc/apt/sources.list.d/docker.list ]; then
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS \
          $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    fi
    
    # Mise à jour en ignorant les erreurs de dépôts non disponibles
    print_info "Mise à jour des dépôts pour Docker..."
    set +e  # Désactiver l'arrêt sur erreur temporairement
    apt-get update -qq 2>&1 | grep -v "questing Release" | grep -v "has no Release file" | grep -v "^E:" > /dev/null
    UPDATE_STATUS=$?
    set -e  # Réactiver l'arrêt sur erreur
    if [ $UPDATE_STATUS -ne 0 ]; then
        print_warn "Certains dépôts peuvent être indisponibles, continuation..."
    fi
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    systemctl enable docker
    systemctl start docker
    
    print_info "✅ Docker installé et démarré"
fi

# Vérifier docker-compose
if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
    if command -v docker-compose &> /dev/null; then
        COMPOSE_VERSION=$(docker-compose --version)
    else
        COMPOSE_VERSION=$(docker compose version)
    fi
    print_info "✅ Docker Compose disponible: $COMPOSE_VERSION"
else
    print_warn "Docker Compose non détecté, installation..."
    apt-get install -y -qq docker-compose-plugin
    print_info "✅ Docker Compose installé"
fi
echo ""

# Installation des modules Python
print_info "Installation des modules Python..."
python3 -m pip install --upgrade pip --quiet 2>/dev/null || true
python3 -m pip install docker docker-compose --break-system-packages --quiet 2>/dev/null || {
    print_warn "Installation des modules Python via pip échouée, continuons..."
}
print_info "✅ Modules Python installés"
echo ""

# Configuration Docker
print_info "Configuration des permissions Docker..."
if [ -n "$SUDO_USER" ]; then
    usermod -aG docker "$SUDO_USER" 2>/dev/null || true
    print_info "✅ Utilisateur $SUDO_USER ajouté au groupe docker"
    print_warn "⚠️  Vous devrez vous déconnecter/reconnecter ou exécuter 'newgrp docker' pour utiliser Docker sans sudo"
fi

if docker ps &> /dev/null; then
    print_info "✅ Docker fonctionne correctement"
else
    print_warn "⚠️  Docker ne répond pas. Essayez de vous déconnecter/reconnecter ou exécutez 'newgrp docker'"
fi

echo ""
print_info "=========================================="
print_info "  DÉPLOIEMENT DE L'INFRASTRUCTURE"
print_info "=========================================="
echo ""

# ==========================================
# PARTIE 2 : DÉPLOIEMENT ANSIBLE
# ==========================================

# Changer vers le répertoire du projet
cd "$SCRIPT_DIR"

# Si l'utilisateur n'est pas root mais a utilisé sudo, utiliser l'utilisateur original
if [ -n "$SUDO_USER" ]; then
    print_info "Déploiement en tant que $SUDO_USER..."
    
    # Vérifier si l'utilisateur peut utiliser docker sans sudo
    if sudo -u "$SUDO_USER" docker ps &> /dev/null; then
        print_info "✅ Docker accessible sans sudo pour $SUDO_USER"
    else
        print_warn "⚠️  Docker nécessite sudo pour $SUDO_USER"
        print_warn "   Cela peut être dû au fait que vous venez d'être ajouté au groupe docker."
        print_warn "   Le playbook va essayer de s'exécuter, mais si cela échoue:"
        print_warn "   1. Déconnectez-vous et reconnectez-vous, OU"
        print_warn "   2. Exécutez dans un nouveau terminal: newgrp docker"
        print_warn "   3. Puis relancez: ansible-playbook ansible/playbooks/deploy-and-test.yml"
        echo ""
    fi
    echo ""
    
    # Exécuter le playbook en tant que l'utilisateur original
    # Le playbook n'utilise plus become: yes, donc pas besoin de sudo
    sudo -u "$SUDO_USER" ansible-playbook ansible/playbooks/deploy-and-test.yml || {
        echo ""
        print_warn "⚠️  Déploiement échoué. Vérifiez les erreurs ci-dessus."
        echo ""
        print_info "Si le problème est lié à Docker, essayez:"
        echo "  newgrp docker"
        echo "  cd $SCRIPT_DIR"
        echo "  ansible-playbook ansible/playbooks/deploy-and-test.yml"
        exit 1
    }
else
    # Si on est déjà root, exécuter directement
    ansible-playbook ansible/playbooks/deploy-and-test.yml || {
        echo ""
        print_warn "⚠️  Déploiement échoué. Vérifiez les erreurs ci-dessus."
        exit 1
    }
fi

echo ""
print_info "=========================================="
print_info "  ✅ TOUT EST TERMINÉ !"
print_info "=========================================="
echo ""
print_info "🌐 Interface Splunk disponible sur: http://localhost:8000"
print_info "   Identifiants: admin / splunk1RT3"
echo ""
print_info "Pour voir les logs en temps réel:"
echo "  docker exec firewall tail -f /var/log/kern.log | grep UFW"
echo "  docker exec logcollector tail -f /var/log/firewall/*.log | grep UFW"
echo ""
