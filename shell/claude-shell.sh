# ==== CLAUDE CODE - 3-MODE ROUTING ====
# Source this file in your .zshrc or .bashrc:
#   source ~/Documents/Code/OTHERS/claude-code-setup/shell/claude-shell.sh
# Or the install script adds it automatically.
#
# Modes:
#   glm-off   -> Full Claude (tout -> Anthropic OAuth)
#   glm-on    -> Hybride (Sonnet/Haiku -> Z.AI proxy, Opus -> Anthropic)
#   glm-full  -> Full GLM (tout -> Z.AI direct, config officielle)
# ============================================================================

GLM_ROUTING_FILE="$HOME/.claude/glm-routing"
ZAI_API_KEY_FILE="$HOME/.claude/.zai-api-key"
GLM_PROXY_DIR="$HOME/Documents/Code/OTHERS/claude-code-setup/proxy"
GLM_PROXY_PY="$GLM_PROXY_DIR/proxy.py"
GLM_PROXY_VENV="$GLM_PROXY_DIR/venv/bin/python"
GLM_PROXY_LOG="/tmp/claude-proxy.log"

_glm_state() {
  if [ -f "$GLM_ROUTING_FILE" ]; then
    cat "$GLM_ROUTING_FILE" 2>/dev/null | tr -d '[:space:]'
  else
    echo "on"
  fi
}

_zai_key() {
  if [ -f "$ZAI_API_KEY_FILE" ]; then
    cat "$ZAI_API_KEY_FILE" 2>/dev/null | tr -d '[:space:]'
  elif [ -f "$GLM_PROXY_DIR/.env" ]; then
    grep "SONNET_PROVIDER_API_KEY=" "$GLM_PROXY_DIR/.env" 2>/dev/null | cut -d= -f2 | tr -d '[:space:]'
  else
    echo ""
  fi
}

_glm_proxy_start() {
  if ! lsof -i:8082 -sTCP:LISTEN &>/dev/null; then
    if [ ! -f "$GLM_PROXY_PY" ]; then
      echo "ERROR: Proxy not found at $GLM_PROXY_PY"
      echo "  Run: cd $GLM_PROXY_DIR && python3 -m venv venv && ./venv/bin/pip install -q -r requirements.txt"
      return 1
    fi
    echo "Starting GLM proxy..."
    PYTHONUNBUFFERED=1 nohup "$GLM_PROXY_VENV" -u "$GLM_PROXY_PY" >"$GLM_PROXY_LOG" 2>&1 &
    sleep 2
    if lsof -i:8082 -sTCP:LISTEN &>/dev/null; then
      echo "Proxy started on port 8082"
    else
      echo "WARNING: Proxy failed to start. Check $GLM_PROXY_LOG"
      return 1
    fi
  fi
}

_glm_proxy_stop() {
  local pid
  pid=$(lsof -ti:8082 -sTCP:LISTEN 2>/dev/null)
  if [ -n "$pid" ]; then
    kill "$pid" 2>/dev/null
    echo "Proxy stopped (PID $pid)"
  fi
}

_glm_env_clean() {
  unset ANTHROPIC_BASE_URL
  unset ANTHROPIC_AUTH_TOKEN
  unset API_TIMEOUT_MS
  unset ANTHROPIC_DEFAULT_OPUS_MODEL
  unset ANTHROPIC_DEFAULT_SONNET_MODEL
  unset ANTHROPIC_DEFAULT_HAIKU_MODEL
  unset DISABLE_PROMPT_CACHING
  unset DISABLE_PROMPT_CACHING_HAIKU
  unset DISABLE_PROMPT_CACHING_SONNET
}

claude() {
  local state
  state=$(_glm_state)

  _glm_env_clean

  case "$state" in
    on)
      _glm_proxy_start || return 1
      export ANTHROPIC_BASE_URL=http://localhost:8082
      export DISABLE_PROMPT_CACHING_HAIKU=1
      export DISABLE_PROMPT_CACHING_SONNET=1
      ;;
    full)
      local key
      key=$(_zai_key)
      if [ -z "$key" ]; then
        echo "ERROR: Z.AI API key not found."
        echo "  Run: echo 'your_key' > ~/.claude/.zai-api-key"
        return 1
      fi
      export ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
      export ANTHROPIC_AUTH_TOKEN="$key"
      export API_TIMEOUT_MS=3000000
      export ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.1
      export ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.1
      export ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.5-air
      export DISABLE_PROMPT_CACHING=1
      export DISABLE_PROMPT_CACHING_HAIKU=1
      export DISABLE_PROMPT_CACHING_SONNET=1
      ;;
    off|*)
      ;;
  esac

  command claude "$@"
}

glm-on() {
  echo "on" > "$GLM_ROUTING_FILE"
  _glm_proxy_start
  echo ""
  echo "Mode HYBRIDE active"
  echo "  Sonnet/Haiku -> Z.AI GLM (proxy)"
  echo "  Opus         -> Anthropic OAuth"
  echo ""
  echo "Relance 'claude' pour appliquer."
}

glm-full() {
  local key
  key=$(_zai_key)
  if [ -z "$key" ]; then
    echo "ERROR: Z.AI API key not configured."
    echo "  Run: echo 'your_zai_key' > ~/.claude/.zai-api-key"
    return 1
  fi
  echo "full" > "$GLM_ROUTING_FILE"
  _glm_proxy_stop
  echo ""
  echo "Mode FULL GLM active"
  echo "  Tout -> Z.AI direct (config officielle)"
  echo "  Pas de proxy, pas de fallback"
  echo ""
  echo "Relance 'claude' pour appliquer."
}

glm-off() {
  echo "off" > "$GLM_ROUTING_FILE"
  _glm_proxy_stop
  echo ""
  echo "Mode FULL CLAUDE active"
  echo "  Tout -> Anthropic OAuth"
  echo ""
  echo "Relance 'claude' pour appliquer."
}

glm-status() {
  local state
  state=$(_glm_state)
  local proxy_running="no"
  if lsof -i:8082 -sTCP:LISTEN &>/dev/null; then
    proxy_running="yes"
  fi

  echo ""
  case "$state" in
    on)
      echo "  Mode:  HYBRIDE"
      echo "  Sonnet/Haiku -> Z.AI GLM-5.1 (proxy :8082)"
      echo "  Opus         -> Anthropic OAuth"
      ;;
    full)
      echo "  Mode:  FULL GLM"
      echo "  Tout -> Z.AI direct (https://api.z.ai/api/anthropic)"
      echo "  Models: opus/sonnet=glm-5.1, haiku=glm-4.5-air"
      echo "  Caching: disabled (no proxy sanitization)"
      ;;
    off)
      echo "  Mode:  FULL CLAUDE"
      echo "  Tout -> Anthropic OAuth"
      ;;
  esac
  echo "  Proxy: $proxy_running"
  echo "  Config: $GLM_ROUTING_FILE ($state)"

  local key
  key=$(_zai_key)
  if [ -n "$key" ]; then
    echo "  Key:   $ZAI_API_KEY_FILE (${#key} chars)"
  else
    echo "  Key:   NOT FOUND"
  fi

  # Health check when proxy is running
  if [ "$proxy_running" = "yes" ]; then
    local health
    health=$(curl -s --max-time 2 http://localhost:8082/health 2>/dev/null)
    if [ -n "$health" ]; then
      local cb_haiku cb_sonnet reqs fallbacks
      cb_haiku=$(echo "$health" | jq -r '.circuit_breaker.haiku // "?"' 2>/dev/null)
      cb_sonnet=$(echo "$health" | jq -r '.circuit_breaker.sonnet // "?"' 2>/dev/null)
      reqs=$(echo "$health" | jq -r '.stats.total_requests // 0' 2>/dev/null)
      fallbacks=$(echo "$health" | jq -r '.stats.fallbacks_to_anthropic // 0' 2>/dev/null)
      echo ""
      echo "  Health:"
      echo "    Requests:  $reqs (fallbacks: $fallbacks)"
      echo "    Haiku CB:  $cb_haiku"
      echo "    Sonnet CB: $cb_sonnet"
    else
      echo ""
      echo "  Health: unreachable (proxy may be degraded)"
    fi
  fi
  echo ""
}

glm-tokens() {
  local state
  state=$(_glm_state)
  if [ "$state" != "on" ]; then
    echo "Disponible uniquement en mode hybride (actuel: $state)"
    return 1
  fi
  if ! lsof -i:8082 -sTCP:LISTEN &>/dev/null; then
    echo "Proxy not running."
    return 1
  fi
  curl -s http://localhost:8082/stats/tokens | python3 -m json.tool
}

glm-key() {
  local key
  key=$(_zai_key)
  if [ -n "$key" ]; then
    echo "Z.AI API key configured (${#key} chars)"
    echo "  File: $ZAI_API_KEY_FILE"
  else
    echo "No Z.AI API key found."
    echo "  Set it with: echo 'your_key' > ~/.claude/.zai-api-key"
  fi
}

glm-setup() {
  echo "Setting up proxy at $GLM_PROXY_DIR..."
  if [ -d "$GLM_PROXY_DIR/venv" ]; then
    echo "  Venv already exists. Use glm-status to check."
    return 0
  fi
  if [ -d "$GLM_PROXY_DIR" ]; then
    echo "  Creating venv..."
    echo ""
    echo "  Run this command manually:"
    echo ""
    echo "    cd $GLM_PROXY_DIR"
    echo "    cp .env.example .env"
    echo "    python3 -m venv venv"
    echo "    ./venv/bin/pip install -q -r requirements.txt"
    echo ""
    echo "  Then edit $GLM_PROXY_DIR/.env with your Z.AI API key."
    echo "  (It's also read from ~/.claude/.zai-api-key)"
  else
    echo "  Source repo not found. Clone it first:"
    echo "    git clone git@github.com:louis-tepe/claude-code-setup.git ~/Documents/Code/OTHERS/claude-code-setup"
  fi
}

alias cc='claude --dangerously-skip-permissions'
alias glm-logs='tail -f /tmp/claude-proxy.log'
# ==== END CLAUDE CODE 3-MODE ROUTING ====
