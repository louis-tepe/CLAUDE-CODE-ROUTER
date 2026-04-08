# Claude Code Setup — Multi-Provider Router

> Use Claude Code with **multiple LLM providers** (Z.AI GLM, MiniMax, or any Anthropic-compatible API) via a local proxy. The main agent (Opus) stays on Anthropic while sub-tasks route through cheaper/faster providers.

## 5 Routing Modes

| Command | Mode | Description |
|---------|------|-------------|
| `claude-full` | **Full Claude** | All → Anthropic OAuth (native, zero overhead) |
| `glm-on` | **Hybrid GLM** | Sonnet → GLM-5.1, Haiku → GLM-4.7, Opus → Anthropic |
| `minimax-on` | **Hybrid MiniMax** | Sonnet/Haiku → MiniMax M2.7, Opus → Anthropic |
| `mix-on` | **Split** | Sonnet → GLM-5.1, Haiku → MiniMax M2.7, Opus → Anthropic |
| `glm-full` | **Full GLM** | All → Z.AI direct (official config, no proxy) |

### How it works

```
                    ┌──────────────────────────────────────────────┐
  claude-full       │  FULL CLAUDE                                  │
                    │  All requests → Anthropic OAuth (native)      │
                    ├──────────────────────────────────────────────┤
  glm-on            │  HYBRID GLM                                   │
                    │  Opus → Anthropic | Sonnet → GLM-5.1          │
                    │                   | Haiku  → GLM-4.7          │
                    ├──────────────────────────────────────────────┤
  minimax-on        │  HYBRID MINIMAX                               │
                    │  Opus → Anthropic | Sonnet/Haiku → MiniMax    │
                    ├──────────────────────────────────────────────┤
  mix-on            │  SPLIT (best of both)                         │
                    │  Opus → Anthropic | Sonnet → GLM-5.1          │
                    │                   | Haiku  → MiniMax M2.7     │
                    ├──────────────────────────────────────────────┤
  glm-full          │  FULL GLM                                     │
                    │  All requests → Z.AI direct (no proxy)        │
                    └──────────────────────────────────────────────┘
```

### Proxy features
- **Circuit breaker**: auto-bypass provider after 5 failures (120s recovery)
- **Automatic fallback**: web_search, vision, PDF → Anthropic transparently
- **Model-based pricing**: accurate cost display from built-in `MODEL_PRICING` table
- **Request sanitization**: strips Anthropic-specific params for provider compatibility
- **Per-tier caching**: respects each provider's cache_control support

---

## Prerequisites

| Requirement | Check | Install |
|-------------|-------|---------|
| **macOS or Linux** | `uname -s` | — |
| **Python 3.10+** | `python3 --version` | `brew install python3` |
| **jq** | `jq --version` | `brew install jq` |
| **Node.js 18+** | `node --version` | `brew install node` |
| **Claude Code** | `claude --version` | `npm install -g @anthropic-ai/claude-code` |
| **Claude Max subscription** | [claude.ai/settings](https://claude.ai/settings) | Required for Opus via OAuth |
| **GLM Coding Plan** (optional) | [z.ai/subscribe](https://z.ai/subscribe) | From $10/month |
| **MiniMax API key** (optional) | [platform.minimax.io](https://platform.minimax.io) | Pay-as-you-go |

---

## Installation

### Step 1 — Clone

```bash
git clone git@github.com:louis-tepe/claude-code-setup.git ~/claude-code-setup
cd ~/claude-code-setup
```

### Step 2 — Install

```bash
./install.sh
```

The script will:
1. Check prerequisites (Python, jq, Node.js)
2. Install the proxy + Python dependencies
3. Copy Claude Code config (settings, agents, statusline)
4. Copy mode files to `~/.claude/proxy-modes/`
5. Add shell integration to `~/.zshrc` (or `.bashrc`)
6. Prompt for API keys
7. Test the proxy

### Step 3 — Reload terminal

```bash
source ~/.zshrc
```

### Step 4 — Configure API keys

```bash
# Z.AI (for GLM modes)
echo 'your_zai_key' > ~/.claude/.zai-api-key

# MiniMax (for MiniMax/mix modes)
echo 'your_minimax_key' > ~/.claude/.minimax-api-key
```

### Step 5 — Choose a mode and launch

```bash
minimax-on    # or glm-on, mix-on, claude-full
claude
```

---

## Commands

### Mode switching
| Command | Description |
|---------|-------------|
| `glm-on` | Hybrid GLM (Sonnet → GLM-5.1, Haiku → GLM-4.7) |
| `minimax-on` | Hybrid MiniMax (Sonnet/Haiku → MiniMax M2.7) |
| `mix-on` | Split (Sonnet → GLM-5.1, Haiku → MiniMax M2.7) |
| `glm-full` | Full GLM (all → Z.AI direct) |
| `claude-full` | Full Claude (all → Anthropic) |

### Utilities
| Command | Description |
|---------|-------------|
| `proxy-status` | Show current mode, routing, health |
| `proxy-tokens` | Token usage and cost stats |
| `proxy-keys` | Check configured API keys |
| `proxy-logs` | Proxy logs in real time |
| `proxy-setup` | Setup instructions |

---

## Architecture

```
~/.claude/                          # User config (never in git)
├── proxy-routing                   # Current mode state (on/minimax/mix/full/off)
├── proxy-modes/                    # Provider config per mode
│   ├── on.env                      # GLM hybrid config
│   ├── minimax.env                 # MiniMax hybrid config
│   └── mix.env                     # Split GLM+MiniMax config
├── .zai-api-key                    # Z.AI API key
├── .minimax-api-key                # MiniMax API key
├── claude-shell.sh                 # Shell wrapper (sourced by .zshrc)
└── statusline-command.sh           # Status bar display

claude-code-setup/                  # Source code (git repo)
├── proxy/
│   ├── proxy.py                    # FastAPI proxy (Multi-Provider Router v5)
│   ├── .env                        # Operational config (port, log level)
│   └── requirements.txt            # Python deps
├── proxy-modes/                    # Mode file templates
├── shell/claude-shell.sh           # Shell source
├── claude-config/                  # Claude Code config templates
└── install.sh                      # Installer
```

### Adding a new provider

1. Create API key file: `echo 'key' > ~/.claude/.newprovider-api-key`
2. Create mode file `~/.claude/proxy-modes/newprovider.env`:
   ```env
   _SHELL_SONNET_KEY=.newprovider-api-key
   _SHELL_HAIKU_KEY=.newprovider-api-key
   SONNET_PROVIDER_BASE_URL=https://api.newprovider.com/anthropic
   HAIKU_PROVIDER_BASE_URL=https://api.newprovider.com/anthropic
   PROVIDER_SONNET_MODEL=newprovider-model
   PROVIDER_HAIKU_MODEL=newprovider-model
   ```
3. Add pricing to `proxy.py` `MODEL_PRICING` table
4. Add shell command: `newprovider-on() { _switch_mode newprovider; }`
5. Add display case in `proxy-status()`

### Mode env file format

```env
# Shell directives (not passed to proxy)
_SHELL_SONNET_KEY=.keyfile          # Key file relative to ~/.claude/
_SHELL_HAIKU_KEY=.keyfile           # Key file relative to ~/.claude/
_SHELL_DISABLE_CACHING_SONNET=1    # Disable prompt caching for Sonnet
_SHELL_DISABLE_CACHING_HAIKU=1     # Disable prompt caching for Haiku

# Proxy env vars (passed to proxy process)
SONNET_PROVIDER_BASE_URL=https://...
HAIKU_PROVIDER_BASE_URL=https://...
PROVIDER_SONNET_MODEL=model-name
PROVIDER_HAIKU_MODEL=model-name
PROVIDER_PASS_CACHE_CONTROL=1       # Pass cache_control to provider
```

---

## Pricing

Pricing is resolved automatically by model name in `proxy.py`:

| Model | Input/M | Output/M | Provider |
|-------|---------|----------|----------|
| GLM-5.1 | $1.40 | $4.40 | Z.AI |
| GLM-4.7 | $0.60 | $2.20 | Z.AI |
| MiniMax M2.7 | $0.30 | $1.20 | MiniMax |
| Claude Sonnet 4.6 | $3.00 | $15.00 | Anthropic |
| Claude Haiku 4.5 | $1.00 | $5.00 | Anthropic |

---

## Troubleshooting

### Proxy won't start
```bash
proxy-status                    # Check current state
proxy-logs                      # Check error logs
lsof -i:8082                   # Port already in use?
```

### API key issues
```bash
proxy-keys                      # Check all configured keys
```

### Switch to safe mode
```bash
claude-full                     # Bypass proxy, use Anthropic directly
```

---

## Credits

- Proxy originally based on [jodavan/claude-code-proxy](https://github.com/jodavan/claude-code-proxy)
- GLM models by [Zhipu AI / Z.AI](https://z.ai)
- MiniMax models by [MiniMax](https://minimax.io)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) by Anthropic
