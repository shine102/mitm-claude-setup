# claude-mitm

Intercept and modify Claude Code API responses using mitmproxy. Runs as a systemd user service so modifications persist across reboots.

## Project structure

```
claude-mitm/
├── scripts/
│   └── modify_response.py    # mitmproxy addon script
├── overrides/
│   ├── settings.json          # your settings override (gitignored)
│   ├── policy_limits.json     # your policy_limits override (gitignored)
│   ├── settings.example.json
│   └── policy_limits.example.json
├── systemd/
│   └── mitmproxy.service      # systemd user service unit
├── setup.sh                   # one-command setup
└── README.md
```

## Prerequisites

- Linux with systemd (tested on Fedora 43)
- Python 3.10+
- Claude Code CLI installed

## Setup

### 1. Clone and run setup

```bash
git clone <repo-url> ~/code/claude-mitm
cd ~/code/claude-mitm
./setup.sh
source ~/.bashrc
```

### 2. Create your override files

```bash
cp overrides/settings.example.json overrides/settings.json
cp overrides/policy_limits.example.json overrides/policy_limits.json
```

Edit the JSON files to your needs. Any file that doesn't exist in `overrides/` will be skipped (the original response passes through).

### 3. Restart the service after editing overrides

```bash
systemctl --user restart mitmproxy.service
```

Or just edit the files — the script re-reads them on every request so changes take effect on next `claude` launch without a service restart.

## Usage

Just run `claude` as normal. The alias routes traffic through mitmproxy automatically.

```bash
claude
```

## Supported endpoints

| Endpoint | Override file | Replaces |
|---|---|---|
| `/api/claude_code/settings` | `overrides/settings.json` | `settings` key in response |
| `/api/claude_code/policy_limits` | `overrides/policy_limits.json` | entire response body |

To add more endpoints, edit `ROUTES` in `scripts/modify_response.py`.

## Managing the service

```bash
# Status
systemctl --user status mitmproxy.service

# Logs
journalctl --user -u mitmproxy.service -f

# Restart
systemctl --user restart mitmproxy.service

# Stop
systemctl --user stop mitmproxy.service

# Disable (remove from boot)
systemctl --user disable mitmproxy.service
```

## Uninstall

```bash
systemctl --user stop mitmproxy.service
systemctl --user disable mitmproxy.service
rm ~/.config/systemd/user/mitmproxy.service
systemctl --user daemon-reload
rm -rf ~/mitmproxy-venv
# Remove the alias line from ~/.bashrc
```

## Inspecting traffic

To capture raw traffic for analysis:

```bash
systemctl --user stop mitmproxy.service
~/mitmproxy-venv/bin/mitmweb
```

Then in another terminal run Claude with the proxy env vars. Open http://127.0.0.1:8081 to browse requests/responses interactively. Start the service again when done.
