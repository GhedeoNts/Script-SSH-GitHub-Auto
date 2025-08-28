#!/bin/bash

# Script de configuration SSH pour GitHub avec chargement automatique
# Compatible Ubuntu Linux avec Zsh

echo "🔑 Configuration SSH pour GitHub - Script interactif"
echo "================================================="

# Fonction pour vérifier si une commande existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Vérifier les prérequis
if ! command_exists ssh-keygen; then
    echo "❌ ssh-keygen n'est pas installé. Installation..."
    sudo apt update && sudo apt install -y openssh-client
fi

if ! command_exists git; then
    echo "❌ git n'est pas installé. Installation..."
    sudo apt update && sudo apt install -y git
fi

# 1. Générer la clé SSH
echo -e "\n📝 Étape 1: Génération de la clé SSH"
echo "=====================================\n"

read -p "Entrez votre email GitHub: " email
if [ -z "$email" ]; then
    echo "❌ Email requis pour générer la clé SSH"
    exit 1
fi

# Vérifier si une clé existe déjà
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "⚠️  Une clé SSH existe déjà (~/.ssh/id_ed25519)"
    read -p "Voulez-vous la remplacer ? (y/N): " replace
    if [[ $replace =~ ^[Yy]$ ]]; then
        rm -f ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub
    else
        echo "✅ Utilisation de la clé existante"
    fi
fi

# Générer la clé si elle n'existe pas
if [ ! -f ~/.ssh/id_ed25519 ]; then
    echo "🔐 Génération de la clé SSH ED25519..."
    ssh-keygen -t ed25519 -C "$email" -f ~/.ssh/id_ed25519 -N ""
    echo "✅ Clé SSH générée avec succès"
fi

# 2. Configuration du ssh-agent automatique
echo -e "\n🤖 Étape 2: Configuration du ssh-agent automatique"
echo "================================================\n"

# Créer le répertoire .ssh s'il n'existe pas
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Configuration pour le chargement automatique dans .zshrc
ZSHRC_CONFIG='
# Configuration SSH Agent pour GitHub
SSH_ENV="$HOME/.ssh/agent-environment"

function start_agent {
    echo "Initialisation du ssh-agent..."
    /usr/bin/ssh-agent | sed '\''s/^echo/#echo/'\'' > "${SSH_ENV}"
    echo "ssh-agent démarré"
    chmod 600 "${SSH_ENV}"
    . "${SSH_ENV}" > /dev/null
    /usr/bin/ssh-add ~/.ssh/id_ed25519 2>/dev/null
}

# Vérifier si ssh-agent est déjà en cours d'\''exécution
if [ -f "${SSH_ENV}" ]; then
    . "${SSH_ENV}" > /dev/null
    ps -ef | grep ${SSH_AGENT_PID} | grep ssh-agent$ > /dev/null || {
        start_agent
    }
else
    start_agent
fi'

# Sauvegarder le .zshrc actuel
if [ -f ~/.zshrc ]; then
    cp ~/.zshrc ~/.zshrc.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Sauvegarde de .zshrc créée"
fi

# Vérifier si la configuration existe déjà
if ! grep -q "SSH_ENV=" ~/.zshrc 2>/dev/null; then
    echo "$ZSHRC_CONFIG" >> ~/.zshrc
    echo "✅ Configuration ajoutée à ~/.zshrc"
else
    echo "⚠️  Configuration SSH déjà présente dans ~/.zshrc"
fi

# 3. Configuration SSH
echo -e "\n⚙️  Étape 3: Configuration SSH"
echo "===============================\n"

# Créer le fichier config SSH
SSH_CONFIG='# Configuration GitHub
Host github.com
    HostName github.com
    User git
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    AddKeysToAgent yes'

if [ ! -f ~/.ssh/config ] || ! grep -q "Host github.com" ~/.ssh/config; then
    echo "$SSH_CONFIG" >> ~/.ssh/config
    chmod 600 ~/.ssh/config
    echo "✅ Configuration SSH ajoutée"
else
    echo "⚠️  Configuration GitHub déjà présente dans ~/.ssh/config"
fi

# 4. Démarrer ssh-agent et ajouter la clé
echo -e "\n🚀 Étape 4: Activation de la clé SSH"
echo "===================================\n"

eval "$(ssh-agent -s)" > /dev/null 2>&1
ssh-add ~/.ssh/id_ed25519 2>/dev/null

if [ $? -eq 0 ]; then
    echo "✅ Clé SSH ajoutée à l'agent"
else
    echo "⚠️  Erreur lors de l'ajout de la clé à l'agent"
fi

# 5. Afficher la clé publique pour GitHub
echo -e "\n📋 Étape 5: Clé publique à ajouter sur GitHub"
echo "============================================\n"

echo "Voici votre clé SSH publique à copier dans GitHub :"
echo "👉 Allez sur : https://github.com/settings/keys"
echo "👉 Cliquez sur 'New SSH key'"
echo "👉 Collez la clé ci-dessous :\n"

echo "--- DÉBUT DE LA CLÉ ---"
cat ~/.ssh/id_ed25519.pub
echo "--- FIN DE LA CLÉ ---"

echo -e "\n📱 La clé a été copiée dans le presse-papiers (si xclip est disponible)"
if command_exists xclip; then
    cat ~/.ssh/id_ed25519.pub | xclip -selection clipboard
    echo "✅ Clé copiée dans le presse-papiers"
elif command_exists pbcopy; then
    cat ~/.ssh/id_ed25519.pub | pbcopy
    echo "✅ Clé copiée dans le presse-papiers"
else
    echo "💡 Installez xclip pour copier automatiquement : sudo apt install xclip"
fi

# 6. Test de connexion
echo -e "\n🧪 Étape 6: Test de la connexion GitHub"
echo "======================================\n"

read -p "Avez-vous ajouté la clé sur GitHub ? (y/N): " added_key

if [[ $added_key =~ ^[Yy]$ ]]; then
    echo "Test de connexion à GitHub..."
    ssh -T git@github.com 2>&1 | head -n 3
    
    if [ $? -eq 1 ]; then  # ssh -T retourne 1 pour GitHub mais c'est normal
        echo "✅ Connexion SSH à GitHub réussie !"
    else
        echo "⚠️  Vérifiez que vous avez bien ajouté la clé sur GitHub"
    fi
else
    echo "💡 N'oubliez pas d'ajouter votre clé SSH sur GitHub !"
fi

# 7. Instructions finales
echo -e "\n🎉 Configuration terminée !"
echo "==========================\n"

echo "📝 Ce qui a été configuré :"
echo "  • Clé SSH ED25519 générée"
echo "  • ssh-agent configuré pour démarrage automatique"
echo "  • Configuration ajoutée à ~/.zshrc"
echo "  • Fichier ~/.ssh/config configuré"
echo ""
echo "🔄 Pour appliquer les changements immédiatement :"
echo "   source ~/.zshrc"
echo ""
echo "🚀 À partir de maintenant, à chaque nouvelle session zsh :"
echo "  • ssh-agent démarrera automatiquement"
echo "  • Votre clé SSH sera chargée automatiquement"
echo "  • Plus besoin de taper ssh-add manuellement !"
echo ""
echo "🔗 Test rapide : git clone git@github.com:username/repository.git"

# Option pour redémarrer zsh
read -p "Voulez-vous redémarrer zsh maintenant ? (y/N): " restart_zsh
if [[ $restart_zsh =~ ^[Yy]$ ]]; then
    exec zsh
fi
