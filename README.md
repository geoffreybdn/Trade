# Bot de trading Freqtrade × Binance

Projet de départ pour [Freqtrade](https://github.com/freqtrade/freqtrade), branché sur Binance (spot, USDT).
Il démarre en **dry-run** : le bot trade avec de l'argent fictif (1000 USDT), sans passer de vrais ordres.
Tu le pilotes depuis ton téléphone grâce à une **app installable (PWA)**, accessible de façon privée via Tailscale.

```
 Téléphone (PWA)  ──HTTPS privé Tailscale──▶  PC / VPS : nginx ▶ Freqtrade  ──API──▶  Binance
```

Les clés Binance restent sur le PC/VPS : le téléphone n'y a jamais accès, il parle seulement au bot.

```
freqtrade-bot/
├── docker-compose.yml            # lance le bot + l'app web + Tailscale
├── .env.example                  # modèle pour tes clés API (à copier en .env)
├── pwa/                          # transforme FreqUI en app installable (manifest, icônes, service worker)
├── tailscale/serve.json          # expose l'app en HTTPS sur ton réseau privé Tailscale
└── user_data/
    ├── config.json               # réglages : paires, mise, dry-run, etc.
    └── strategies/
        └── EmaRsiStrategy.py     # stratégie d'exemple (croisement EMA + filtre RSI)
```

> ⚠️ Le trading automatique peut te faire perdre de l'argent. Cette stratégie est un exemple pour apprendre, pas une
> stratégie rentable garantie. Ne mise que ce que tu peux te permettre de perdre.

## 🚀 Installation rapide, uniquement depuis ton téléphone

Le bot doit tourner sur un serveur allumé 24h/24. On loue un petit serveur (VPS) et on installe tout en une commande.
Compte environ 20 minutes et 4 à 5 €/mois.

### Étape 1 : Tailscale (le réseau privé entre ton téléphone et le bot)

1. Installe l'app **Tailscale** ([Android](https://play.google.com/store/apps/details?id=com.tailscale.ipn) /
   [iPhone](https://apps.apple.com/app/tailscale/id1470499037)), crée un compte et active-la.
2. Dans ton navigateur, va sur <https://login.tailscale.com/admin/dns> et active **MagicDNS**, puis
   **HTTPS Certificates** (en bas de la page).
3. Va sur <https://login.tailscale.com/admin/settings/keys> → **Generate auth key** → **Generate key**.
   Copie la clé `tskey-auth-...` et garde-la sous la main.

### Étape 2 : louer le serveur (VPS)

Exemple avec [Hetzner](https://www.hetzner.com/cloud) (Europe, pas cher). N'importe quel VPS Ubuntu convient,
mais **choisis un datacenter en Europe** : Binance bloque les serveurs situés aux États-Unis.

1. Crée un compte Hetzner Cloud, puis **New project → Add Server**.
2. Location : **Falkenstein**, **Nuremberg** ou **Helsinki**. Image : **Ubuntu 24.04**. Type : le moins cher (2 vCPU, 4 Go de RAM).
3. Valide. Hetzner t'envoie par e-mail l'**adresse IP** du serveur et le **mot de passe root**.

### Étape 3 : se connecter au serveur depuis le téléphone

1. Installe l'app **Termius** ([Android](https://play.google.com/store/apps/details?id=com.server.auditor.ssh.client) /
   [iPhone](https://apps.apple.com/app/termius-terminal-ssh-client/id549039908)), gratuite.
2. **New Host** : *Address* = l'IP du serveur, *Username* = `root`, *Password* = le mot de passe reçu par e-mail.
3. Connecte-toi. Au premier login, Hetzner peut te demander de changer le mot de passe : fais-le.

### Étape 4 : installer le bot (une seule commande)

Copie-colle cette ligne dans Termius, puis appuie sur Entrée :

```bash
curl -fsSL https://raw.githubusercontent.com/geoffreybdn/trade/main/install.sh | bash
```

Le script installe Docker, télécharge le bot, puis te demande :
- ta **clé Tailscale** (étape 1) ;
- un **mot de passe** pour l'app ;
- tes clés Binance : **appuie sur Entrée pour passer**, le bot démarre en argent fictif.

À la fin, il affiche l'**adresse de ton app** (`https://freqtrade.xxxx.ts.net`) et l'**IP du serveur**.

### Étape 5 : installer l'app sur l'écran d'accueil

Tailscale doit être activé sur le téléphone. Ouvre l'adresse affichée :
- **Android (Chrome)** : menu ⋮ → **Installer l'application**
- **iPhone (Safari, obligatoirement)** : bouton Partager → **Sur l'écran d'accueil**

Le premier chargement peut prendre jusqu'à une minute, le temps de créer le certificat HTTPS.
Dans l'app, connecte-toi avec l'identifiant `freqtrader` et ton mot de passe. Laisse « API Url » tel quel.

### Plus tard : brancher ton vrai compte Binance

1. Crée ta clé API Binance (voir la section 2 plus bas) et mets l'**IP du serveur** dans la restriction IP.
2. Dans Termius : `bash /opt/freqtrade-bot/binance-keys.sh`
3. Après 1 à 2 semaines de test en argent fictif, passe en réel (voir la section 6).

### Dépannage

| Problème | Solution |
|---|---|
| Pas de bouton « Installer » | Vérifie que l'adresse commence par `https://` et que tu es dans Chrome (Android) ou Safari (iPhone) |
| La page ne s'ouvre pas | Active Tailscale sur le téléphone. Vérifie que l'appareil `freqtrade` apparaît sur login.tailscale.com/admin/machines |
| « Tailscale ne répond pas » à la fin de l'installation | La clé Tailscale est peut-être expirée : génère-en une nouvelle, puis relance avec `rm /opt/freqtrade-bot/.env` et la commande d'installation |
| Voir ce que fait le bot | `docker compose -f /opt/freqtrade-bot/docker-compose.yml logs -f freqtrade` |

Sur login.tailscale.com/admin/machines, clique sur `...` à côté de `freqtrade` → **Disable key expiry**,
sinon l'app se déconnecte au bout de 90 jours.

---

Les sections suivantes détaillent une installation manuelle (PC ou serveur).

## 1. Prérequis

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows / Mac) ou Docker + Docker Compose (Linux / VPS)
- Un compte Binance vérifié (KYC)
- Un compte [Tailscale](https://tailscale.com) gratuit, pour accéder au bot depuis ton téléphone

## 2. Créer la clé API Binance

1. Binance → **Profil → Gestion des API → Créer une API** (type « générée par le système »).
2. Permissions :
   - ✅ **Activer la lecture**
   - ✅ **Activer le trading spot et sur marge**
   - ❌ **Ne jamais activer les retraits**
3. **Restreindre l'accès à des IP de confiance** : mets l'IP publique de la machine où tourne le bot
   (indispensable sur un VPS, et Binance désactive le trading sur les clés sans restriction IP au bout d'un moment).
4. Note la *API Key* et la *Secret Key* (la Secret n'est affichée qu'une seule fois).

## 3. Configuration

```bash
cp .env.example .env
```

Ouvre `.env` et remplis :

- `FREQTRADE__EXCHANGE__KEY` / `FREQTRADE__EXCHANGE__SECRET` : tes clés Binance
- `FREQTRADE__API_SERVER__PASSWORD` : mot de passe de l'interface web
- `FREQTRADE__API_SERVER__JWT_SECRET_KEY` et `FREQTRADE__API_SERVER__WS_TOKEN` : de longues chaînes aléatoires
  (par ex. `openssl rand -hex 32`). La clé JWT doit faire au moins 32 caractères, sinon Freqtrade refuse de démarrer.
- `TS_AUTHKEY` : clé Tailscale (voir la section « App sur ton téléphone » plus bas)

Les clés restent dans `.env` (ignoré par git), jamais dans `config.json`. Ne les envoie à personne.

Réglages utiles dans `user_data/config.json` :

| Clé | Valeur | Rôle |
|---|---|---|
| `dry_run` | `true` | `true` = argent fictif, `false` = argent réel |
| `dry_run_wallet` | `1000` | capital fictif en USDT |
| `max_open_trades` | `3` | nombre de positions ouvertes en même temps |
| `stake_amount` | `"unlimited"` | répartit le solde entre les trades (ou un montant fixe, ex. `20`) |
| `pair_whitelist` | BTC, ETH, SOL, BNB, XRP | paires tradées |

## 4. Backtest (tester sur l'historique)

```bash
docker compose pull

# Télécharger l'historique Binance
docker compose run --rm freqtrade download-data \
  --config /freqtrade/user_data/config.json --timerange 20250101- -t 1h

# Rejouer la stratégie sur cet historique
docker compose run --rm freqtrade backtesting \
  --config /freqtrade/user_data/config.json --strategy EmaRsiStrategy --timerange 20250101-
```

Optionnel, chercher de meilleurs paramètres (attention au sur-apprentissage) :

```bash
docker compose run --rm freqtrade hyperopt \
  --config /freqtrade/user_data/config.json --strategy EmaRsiStrategy \
  --hyperopt-loss SharpeHyperOptLoss --spaces buy sell -e 200
```

## 5. Lancer le bot en dry-run

```bash
docker compose up -d
docker compose logs -f        # suivre les logs (Ctrl+C pour quitter)
```

Interface web : <http://127.0.0.1:8080>. Connecte-toi avec l'utilisateur et le mot de passe de `.env`.

Laisse-le tourner **au moins 1 à 2 semaines** en dry-run et compare avec le backtest.

## 📱 App sur ton téléphone (PWA)

FreqUI s'installe comme une vraie app (icône sur l'écran d'accueil, plein écran) : suivi des trades, profits, solde,
graphiques, et boutons pour forcer une sortie, mettre le bot en pause, etc.

Pour que le téléphone joigne le bot de partout (4G, Wi-Fi) **sans l'exposer sur Internet**, on passe par Tailscale,
un réseau privé chiffré entre tes appareils.

**Une seule fois, sur le site Tailscale :**

1. Crée un compte sur <https://login.tailscale.com>.
2. Va dans **DNS** et active **MagicDNS**, puis, plus bas, **HTTPS Certificates**. C'est indispensable : une PWA
   ne s'installe qu'en HTTPS.
3. Va dans **Settings → Keys → Generate auth key**, puis copie la clé (`tskey-auth-...`) dans `TS_AUTHKEY` dans `.env`.
4. Lance `docker compose up -d`. Dans **Machines**, un appareil `freqtrade` apparaît. Clique sur `...` →
   **Disable key expiry** pour qu'il ne se déconnecte pas au bout de 90 jours.
   Son adresse ressemble à `https://freqtrade.tail1234.ts.net` : c'est l'adresse de ton app.

**Sur ton téléphone :**

1. Installe l'app **Tailscale** ([Android](https://play.google.com/store/apps/details?id=com.tailscale.ipn) /
   [iPhone](https://apps.apple.com/app/tailscale/id1470499037)), connecte-toi avec le même compte et active-la.
2. Ouvre `https://freqtrade.<ton-tailnet>.ts.net` :
   - **Android (Chrome)** : menu ⋮ → **Installer l'application**
   - **iPhone (Safari)** : bouton Partager → **Sur l'écran d'accueil**
3. Ouvre l'app « Freqtrade » depuis l'écran d'accueil et connecte-toi :
   - *Bot Name* : ce que tu veux (ex. `binance-bot`)
   - *API Url* : laisse la valeur pré-remplie (l'adresse de l'app)
   - *Username / Password* : ceux de `.env`

Le premier accès peut prendre quelques secondes, le temps que Tailscale obtienne le certificat HTTPS.
Si le bot est injoignable (Tailscale coupé, PC éteint), l'app affiche une page « Bot injoignable » avec un bouton Réessayer.

> 💡 Mets le bot sur un VPS allumé 24h/24 : ton PC peut s'éteindre, ton app restera joignable.

## 6. Passer en réel

1. Dans `user_data/config.json` : `"dry_run": false`
2. Commence petit : remplace `"stake_amount": "unlimited"` par un montant fixe, par ex. `20` (USDT par trade),
   et garde juste ce qu'il faut en USDT sur ton compte spot Binance.
3. Redémarre : `docker compose up -d --force-recreate`

## Commandes utiles

```bash
docker compose stop                # arrêter le bot
docker compose up -d               # le relancer
docker compose pull && docker compose up -d --force-recreate   # mettre Freqtrade à jour
```

Pour faire tourner le bot 24h/24, installe-le sur un petit VPS (2 Go de RAM suffisent) plutôt que sur ton PC.

## Notifications Telegram (optionnel)

1. Crée un bot avec [@BotFather](https://t.me/BotFather) et récupère le token.
2. Récupère ton chat ID avec [@userinfobot](https://t.me/userinfobot).
3. Décommente les lignes `FREQTRADE__TELEGRAM__*` dans `.env`, puis `docker compose up -d --force-recreate`.

Documentation complète : <https://www.freqtrade.io/en/stable/>
