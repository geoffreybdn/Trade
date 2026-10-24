#!/usr/bin/env bash
# Installation complète du bot Freqtrade + app mobile sur un VPS Ubuntu/Debian.
# Usage (en root) :
#   curl -fsSL https://raw.githubusercontent.com/geoffreybdn/trade/main/install.sh | bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/geoffreybdn/trade.git}"
INSTALL_DIR="${INSTALL_DIR:-/opt/freqtrade-bot}"

vert() { printf '\033[1;32m%s\033[0m\n' "$*"; }
jaune() { printf '\033[1;33m%s\033[0m\n' "$*"; }
rouge() { printf '\033[1;31m%s\033[0m\n' "$*" >&2; }

# Les questions sont lues sur le terminal, même quand le script arrive par « curl | bash »
demander() { # demander "Question" [secret]
  local reponse
  if [ "${2:-}" = "secret" ]; then
    read -r -s -p "$1 " reponse </dev/tty; echo >/dev/tty
  else
    read -r -p "$1 " reponse </dev/tty
  fi
  printf '%s' "$reponse"
}

if [ "$(id -u)" -ne 0 ]; then
  rouge "Lance ce script en root (ou avec sudo)."
  exit 1
fi

vert "=== Installation du bot Freqtrade × Binance ==="

# 1. Docker
if ! command -v docker >/dev/null 2>&1; then
  vert "[1/4] Installation de Docker (2-3 minutes)..."
  curl -fsSL https://get.docker.com | sh >/dev/null
else
  vert "[1/4] Docker déjà installé."
fi
command -v git >/dev/null 2>&1 || { apt-get update -qq && apt-get install -y -qq git >/dev/null; }

# 2. Projet
if [ -d "$INSTALL_DIR/.git" ]; then
  vert "[2/4] Mise à jour du projet dans $INSTALL_DIR..."
  git -C "$INSTALL_DIR" pull -q
else
  vert "[2/4] Téléchargement du projet dans $INSTALL_DIR..."
  git clone -q "$REPO_URL" "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"

# 3. Configuration (.env)
if [ -f .env ]; then
  vert "[3/4] Configuration existante conservée ($INSTALL_DIR/.env)."
else
  vert "[3/4] Configuration"
  echo
  jaune "Clé Tailscale (tskey-auth-...) : login.tailscale.com > Settings > Keys > Generate auth key"
  TS_AUTHKEY=$(demander "Colle ta clé Tailscale :" secret)
  while [ -z "$TS_AUTHKEY" ]; do
    TS_AUTHKEY=$(demander "La clé Tailscale est obligatoire. Colle-la :" secret)
  done

  echo
  UI_PASSWORD=$(demander "Choisis un mot de passe pour l'app (au moins 8 caractères) :" secret)
  while [ "${#UI_PASSWORD}" -lt 8 ]; do
    UI_PASSWORD=$(demander "Trop court. Mot de passe (au moins 8 caractères) :" secret)
  done

  echo
  jaune "Clés API Binance : tu peux laisser vide pour l'instant (le bot tourne en argent fictif)"
  jaune "et les ajouter plus tard avec : bash $INSTALL_DIR/binance-keys.sh"
  BINANCE_KEY=$(demander "API Key Binance (Entrée pour passer) :")
  BINANCE_SECRET=""
  if [ -n "$BINANCE_KEY" ]; then
    BINANCE_SECRET=$(demander "Secret Key Binance :" secret)
  fi

  umask 077
  cat > .env <<EOF
FREQTRADE__EXCHANGE__KEY=$BINANCE_KEY
FREQTRADE__EXCHANGE__SECRET=$BINANCE_SECRET
FREQTRADE__API_SERVER__USERNAME=freqtrader
FREQTRADE__API_SERVER__PASSWORD=$UI_PASSWORD
FREQTRADE__API_SERVER__JWT_SECRET_KEY=$(openssl rand -hex 32)
FREQTRADE__API_SERVER__WS_TOKEN=$(openssl rand -hex 24)
TS_AUTHKEY=$TS_AUTHKEY
EOF
  umask 022
fi

# 4. Démarrage
vert "[4/4] Démarrage du bot (le premier téléchargement prend quelques minutes)..."
docker compose pull -q
docker compose up -d

# Adresse Tailscale de l'app
ADRESSE=""
for _ in $(seq 1 60); do
  ADRESSE=$(docker exec freqtrade-tailscale tailscale status --json 2>/dev/null \
    | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null || true)
  [ -n "$ADRESSE" ] && break
  sleep 2
done

IP_PUBLIQUE=$(curl -fsS -4 https://ifconfig.me 2>/dev/null || echo "inconnue")

echo
vert "=============================================="
vert "  Installation terminée !"
vert "=============================================="
if [ -n "$ADRESSE" ]; then
  echo "  Adresse de ton app : https://$ADRESSE"
else
  jaune "  Tailscale ne répond pas encore. Vérifie la clé, puis :"
  jaune "  docker compose -f $INSTALL_DIR/docker-compose.yml logs tailscale"
fi
echo "  Identifiant        : freqtrader"
echo "  Mot de passe       : celui que tu viens de choisir"
echo "  IP du serveur      : $IP_PUBLIQUE  (à mettre dans la restriction IP de ta clé Binance)"
echo
echo "  Le bot tourne en ARGENT FICTIF (dry-run)."
echo "  Logs du bot        : docker compose -f $INSTALL_DIR/docker-compose.yml logs -f freqtrade"
echo
