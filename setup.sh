#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="${MITM_VENV:-$HOME/mitmproxy-venv}"
SCRIPT_PATH="$REPO_DIR/scripts/modify_response.py"
CERT_PATH="$HOME/.mitmproxy/mitmproxy-ca-cert.pem"

echo "==> Creating Python virtual environment..."
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/pip" install mitmproxy

echo "==> Installing systemd user service..."
mkdir -p ~/.config/systemd/user
sed -e "s|__VENV__|$VENV_DIR|g" \
    -e "s|__SCRIPT__|$SCRIPT_PATH|g" \
    "$REPO_DIR/systemd/mitmproxy.service" > ~/.config/systemd/user/mitmproxy.service
systemctl --user daemon-reload
systemctl --user enable mitmproxy.service
systemctl --user start mitmproxy.service

echo "==> Enabling lingering (service persists after logout)..."
loginctl enable-linger "$USER"

echo "==> Generating mitmproxy CA cert (first run)..."
"$VENV_DIR/bin/mitmdump" --set flow_detail=0 -q &
MITM_PID=$!
sleep 2
kill $MITM_PID 2>/dev/null || true

# Pick the rc file for the user's login shell so the alias is actually loaded.
SHELL_NAME="$(basename "${SHELL:-/bin/bash}")"
case "$SHELL_NAME" in
    zsh)  RC_FILE="${ZDOTDIR:-$HOME}/.zshrc" ;;
    bash) RC_FILE="$HOME/.bashrc" ;;
    fish) RC_FILE="$HOME/.config/fish/config.fish" ;;
    *)    RC_FILE="$HOME/.profile" ;;
esac

echo "==> Adding claude alias to $RC_FILE..."
mkdir -p "$(dirname "$RC_FILE")"
# `env VAR=val claude` is portable across bash/zsh/fish; the cert path is
# expanded now so it doesn't depend on shell-specific ~ expansion in aliases.
ALIAS_BODY="env HTTP_PROXY=http://127.0.0.1:8080 HTTPS_PROXY=http://127.0.0.1:8080 NODE_EXTRA_CA_CERTS=$CERT_PATH claude"
if ! grep -q 'claude-mitm: route Claude Code' "$RC_FILE" 2>/dev/null; then
    {
        echo ""
        echo "# claude-mitm: route Claude Code through mitmproxy"
        if [ "$SHELL_NAME" = "fish" ]; then
            echo "alias claude \"$ALIAS_BODY\""
        else
            echo "alias claude=\"$ALIAS_BODY\""
        fi
    } >> "$RC_FILE"
fi

echo ""
echo "Done! Reload your shell (e.g. 'source $RC_FILE') then use 'claude' as normal."
echo "Edit overrides in: $REPO_DIR/overrides/"
echo "Check service: systemctl --user status mitmproxy.service"
echo "View logs: journalctl --user -u mitmproxy.service -f"
