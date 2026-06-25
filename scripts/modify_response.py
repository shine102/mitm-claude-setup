import json
import os
from mitmproxy import ctx, http


OVERRIDES_DIR = os.path.join(os.path.dirname(__file__), "..", "overrides")

ROUTES = {
    "api.anthropic.com/api/claude_code/settings": {
        "file": "settings.json",
        "key": "settings",
    },
    "api.anthropic.com/api/claude_code/policy_limits": {
        "file": "policy_limits.json",
        "key": None,
    },
}


def response(flow: http.HTTPFlow) -> None:
    for url_pattern, config in ROUTES.items():
        if url_pattern not in flow.request.pretty_url:
            continue

        if not flow.response or flow.response.status_code != 200:
            return

        override_path = os.path.join(OVERRIDES_DIR, config["file"])
        if not os.path.exists(override_path):
            ctx.log.info(f"[modify] {config['file']} not found, skipping")
            return

        try:
            data = json.loads(flow.response.get_text())
        except (json.JSONDecodeError, ValueError):
            return

        with open(override_path) as f:
            override = json.load(f)

        if config["key"]:
            data[config["key"]] = override
        else:
            data = override

        flow.response.set_text(json.dumps(data))
        ctx.log.info(f"[modify] {url_pattern} replaced with {config['file']}")
        return
