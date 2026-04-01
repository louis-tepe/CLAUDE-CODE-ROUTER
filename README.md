# Claude Code Setup — 3-Mode Routing

> Utilise Claude Code comme un pro avec **3 modes de routage** : Full Claude, Full GLM, ou Hybride. L'agent principal (Opus) peut rester sur Anthropic pendant que les sous-tâches passent par GLM-5.1 de Zhipu AI, ou tout basculer vers GLM.

## Les 3 Modes

| Commande | Mode | Description |
|----------|------|-------------|
| `glm-off` | **Full Claude** | Tout → Anthropic OAuth (natif, 0 overhead) |
| `glm-on` | **Hybride** | Sonnet/Haiku → Z.AI GLM (proxy), Opus → Anthropic |
| `glm-full` | **Full GLM** | Tout → Z.AI direct (config officielle, pas de proxy) |
| `glm-status` | — | Affiche le mode actif |

### Mode Full Claude (`glm-off`)
- Connexion OAuth Anthropic native
- Toutes les fonctionnalités Claude : web search, vision, prompt caching
- Aucun overhead, aucune variable d'environnement
- Utilise ton abonnement Claude Max

### Mode Hybride (`glm-on`) — Par défaut
- Un proxy local route les requêtes par tier :
  - **Opus** → Anthropic OAuth (ton abonnement Max)
  - **Sonnet** → Z.AI GLM-5.1
  - **Haiku** → Z.AI GLM-5.1
- Sanitization automatique (les features incompatibles GLM sont renvoyées vers Anthropic)
- Circuit breaker : après 5 échecs Z.AI, bascule sur Anthropic
- Prompt caching désactivé (Z.AI ne le supporte pas)

### Mode Full GLM (`glm-full`)
- Config officielle Z.AI : `ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic`
- Connexion directe, pas de proxy, pas de sanitization
- Utilise le quota de ton abonnement GLM Coding Plan
- MCP Z.AI disponibles : Vision, Web Search, Web Reader, Zread
- Pas de prompt caching, pas de web_search natif Claude

```
                    ┌──────────────────────────────────────┐
  glm-off           │  FULL CLAUDE                         │
  ─────────         │  ANTHROPIC_BASE_URL = (unset)         │
                    │  → OAuth Anthropic direct             │
                    ├──────────────────────────────────────┤
  glm-on            │  HYBRIDE                              │
  ─────────         │  ANTHROPIC_BASE_URL = localhost:8082  │
  (default)         │  Opus → Anthropic │ Sonnet/Haiku → GLM│
                    ├──────────────────────────────────────┤
  glm-full          │  FULL GLM                             │
  ─────────         │  ANTHROPIC_BASE_URL = api.z.ai        │
                    │  → Z.AI direct, config officielle     │
                    └──────────────────────────────────────┘
```

---

## Pré-requis

| Pré-requis | Comment vérifier | Comment installer |
|------------|-----------------|-------------------|
| **macOS** | Tu es sur Mac | - |
| **Python 3.10+** | `python3 --version` | `brew install python3` |
| **jq** | `jq --version` | `brew install jq` |
| **Node.js 18+** | `node --version` | `brew install node` |
| **Claude Code** | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| **Abonnement Claude Max** | [claude.ai/settings](https://claude.ai/settings) | [claude.ai/upgrade](https://claude.ai/upgrade) |
| **GLM Coding Plan** (optionnel) | [z.ai/subscribe](https://z.ai/subscribe) | À partir de 10$/mois |

---

## Installation (5 minutes)

### Étape 1 — Clone le repo

```bash
git clone git@github.com:louis-tepe/claude-code-setup.git ~/claude-code-setup
```

### Étape 2 — Lance l'installateur

```bash
cd ~/claude-code-setup
./install.sh
```

Le script va :
1. Vérifier les pré-requis (Python, jq, etc.)
2. Installer le proxy dans `~/claude-code-proxy/`
3. Sauvegarder la clé API Z.AI dans `~/.claude/.zai-api-key`
4. Copier la config Claude Code (settings, agents, statusline)
5. Ajouter l'intégration shell dans `~/.zshrc`
6. Tester le proxy

### Étape 3 — Recharge ton terminal

```bash
source ~/.zshrc
```

### Étape 4 — Connecte-toi à Claude

```bash
claude login
```

### Étape 5 — Lance Claude Code

```bash
claude
```

Par défaut, le mode **Hybride** est actif. Change de mode avec `glm-off`, `glm-on`, ou `glm-full`.

---

## Commandes

| Commande | Description |
|----------|-------------|
| `claude` | Lance Claude Code (configuré selon le mode actif) |
| `cc` | Alias pour `claude --dangerously-skip-permissions` |
| `glm-on` | Mode Hybride (Sonnet/Haiku → GLM proxy, Opus → Anthropic) |
| `glm-full` | Mode Full GLM (tout → Z.AI direct) |
| `glm-off` | Mode Full Claude (tout → Anthropic) |
| `glm-status` | Affiche le mode et l'état du proxy |
| `glm-tokens` | Stats de tokens (mode hybride uniquement) |
| `glm-key` | Vérifie la clé API Z.AI |
| `glm-logs` | Logs du proxy en temps réel |

---

## MCP Z.AI (optionnel, pour le mode Full GLM)

Les serveurs MCP exclusifs du GLM Coding Plan peuvent être ajoutés :

```bash
# Vision MCP (analyse d'images/vidéos)
claude mcp add -s user zai-mcp-server \
  --env Z_AI_API_KEY=$(cat ~/.claude/.zai-api-key) Z_AI_MODE=ZAI \
  -- npx -y "@z_ai/mcp-server"

# Web Search
claude mcp add -s user -t http web-search-prime \
  https://api.z.ai/api/mcp/web_search_prime/mcp \
  --header "Authorization: Bearer $(cat ~/.claude/.zai-api-key)"

# Web Reader
claude mcp add -s user -t http web-reader \
  https://api.z.ai/api/mcp/web_reader/mcp \
  --header "Authorization: Bearer $(cat ~/.claude/.zai-api-key)"

# Zread (docs GitHub)
claude mcp add -s user -t http zread \
  https://api.z.ai/api/mcp/zread/mcp \
  --header "Authorization: Bearer $(cat ~/.claude/.zai-api-key)"
```

---

## Fichiers installés

```
~/claude-code-proxy/          # Le proxy (mode hybride)
├── proxy.py                  # Serveur FastAPI
├── .env                      # Clé API Z.AI + config proxy
├── start-proxy.sh            # Démarrage manuel
└── venv/                     # Python isolé

~/.claude/                    # Config Claude Code
├── .zai-api-key              # Clé API Z.AI (pour mode Full GLM)
├── glm-routing               # État du mode (on/off/full)
├── settings.json             # Réglages globaux
├── statusline-command.sh     # Barre de statut (affiche le mode)
└── agents/                   # 7 agents spécialisés

~/.zshrc                      # Intégration shell (3 modes)
```

---

## Dépannage

### Le proxy ne démarre pas (mode hybride)

```bash
lsof -i:8082                  # Port utilisé ?
cat /tmp/claude-proxy.log     # Logs d'erreur
~/claude-code-proxy/start-proxy.sh  # Démarrage manuel
```

### Mode Full GLM ne fonctionne pas

```bash
glm-key                       # Vérifier la clé API
cat ~/.claude/.zai-api-key    # Vérifier le contenu
```

### Revenir au mode par défaut

```bash
glm-on                        # Repasse en mode hybride
```

---

## Crédits

- Proxy basé sur [jodavan/claude-code-proxy](https://github.com/jodavan/claude-code-proxy), adapté pour le routage GLM-5.1
- Modèles GLM par [Zhipu AI](https://z.ai)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) par Anthropic
