#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "==> Creating Python virtual environment..."
python3 -m venv ~/mitmproxy-venv
~/mitmproxy-venv/bin/pip install mitmproxy

echo "==> Installing systemd user service..."
mkdir -p ~/.config/systemd/user
cp "$REPO_DIR/systemd/mitmproxy.service" ~/.config/systemd/user/mitmproxy.service
systemctl --user daemon-reload
systemctl --user enable mitmproxy.service
systemctl --user start mitmproxy.service

echo "==> Enabling lingering (service persists after logout)..."
loginctl enable-linger "$USER"

echo "==> Generating mitmproxy CA cert (first run)..."
~/mitmproxy-venv/bin/mitmdump --set flow_detail=0 -q &
MITM_PID=$!
sleep 2
kill $MITM_PID 2>/dev/null || true

echo "==> Adding claude alias to ~/.bashrc..."
if ! grep -q 'alias claude=.*mitmproxy' ~/.bashrc 2>/dev/null; then
    cat >> ~/.bashrc << 'ALIAS'

# claude-mitm: route Claude Code through mitmproxy
alias claude="HTTP_PROXY=http://127.0.0.1:8080 HTTPS_PROXY=http://127.0.0.1:8080 NODE_EXTRA_CA_CERTS=~/.mitmproxy/mitmproxy-ca-cert.pem claude"
ALIAS
fi

echo ""
echo "Done! Run 'source ~/.bashrc' then use 'claude' as normal."
echo "Edit overrides in: $REPO_DIR/overrides/"
echo "Check service: systemctl --user status mitmproxy.service"
echo "View logs: journalctl --user -u mitmproxy.service -f"
