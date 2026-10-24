#!/usr/bin/env bash
# Ajoute ou remplace les clés API Binance, puis redémarre le bot.
# Usage : bash /opt/freqtrade-bot/binance-keys.sh
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "Fichier .env introuvable : lance d'abord install.sh" >&2
  exit 1
fi

echo "IP de ce serveur (à mettre dans la restriction IP de ta clé Binance) : $(curl -fsS -4 https://ifconfig.me 2>/dev/null || echo inconnue)"
read -r -p "API Key Binance : " KEY </dev/tty
read -r -s -p "Secret Key Binance : " SECRET </dev/tty; echo

# Réécrit uniquement les deux lignes des clés
grep -v '^FREQTRADE__EXCHANGE__\(KEY\|SECRET\)=' .env > .env.tmp
printf 'FREQTRADE__EXCHANGE__KEY=%s\nFREQTRADE__EXCHANGE__SECRET=%s\n' "$KEY" "$SECRET" >> .env.tmp
chmod 600 .env.tmp
mv .env.tmp .env

docker compose up -d --force-recreate freqtrade
echo "Clés enregistrées, bot redémarré."
