#!/bin/bash
# Start Claude Code Proxy — Multi-Provider Router
# Note: prefer using the shell commands (minimax-on, glm-on, mix-on) which
# inject the correct provider config. This script uses proxy/.env defaults.
cd "$(dirname "$0")"
PYTHONUNBUFFERED=1 ./venv/bin/python -u proxy.py 2>&1 | tee /tmp/claude-proxy.log
