# opencode-copilot-models

**Automatically filter OpenCode's model picker to only show GitHub Copilot models your organization has enabled.**

> **Note**: This is a community-developed plugin and is not officially affiliated with OpenCode.ai.

## Problem

When using GitHub Copilot as a provider, OpenCode shows **every** model Copilot exposes — including ones your organization admin has disabled ([#7256](https://github.com/sst/opencode/issues/7256)). Selecting a disabled model produces a cryptic API error at runtime with no way to know in advance which models are actually usable.

## How It Works

At startup, the plugin:

1. Reads your GitHub Copilot OAuth token from OpenCode's auth storage
2. Queries the [Copilot Models API](https://api.githubcopilot.com/models) to discover which models are enabled for your account/organization
3. Filters to chat-capable, picker-enabled models
4. Sets a `whitelist` on the `github-copilot` provider so only available models appear in the picker

The entire process runs in under a second and fails silently if anything goes wrong — it never blocks OpenCode from starting.

## Prerequisites

- [OpenCode](https://opencode.ai) installed and on your `$PATH`
- GitHub Copilot connected in OpenCode (run `opencode` and authenticate via the GitHub Copilot provider)
- [Bun](https://bun.sh) (for dependency installation)

## Installation

### Option A: Install Script (recommended)

```bash
git clone https://github.com/stateofthehart/opencode-copilot-models.git /tmp/opencode-copilot-models
bash /tmp/opencode-copilot-models/install.sh
rm -rf /tmp/opencode-copilot-models
```

### Option B: Manual Install

```bash
# 1. Clone into the plugins directory
mkdir -p ~/.opencode/plugins
git clone https://github.com/YOUR_USERNAME/opencode-copilot-models.git \
  ~/.opencode/plugins/opencode-copilot-models

# 2. Install dependencies
cd ~/.opencode/plugins/opencode-copilot-models
bun install

# 3. Install into OpenCode's module cache
mkdir -p ~/.cache/opencode/node_modules
ln -sf ~/.opencode/plugins/opencode-copilot-models \
  ~/.cache/opencode/node_modules/opencode-copilot-models

# 4. Register the plugin in ~/.config/opencode/opencode.json
# Add "opencode-copilot-models" to the "plugin" array:
```

```json
{
  "plugin": [
    "opencode-copilot-models"
  ]
}
```

Then restart OpenCode.

## Configuration

**None required.** This is a zero-config plugin. It reads your existing Copilot credentials and dynamically discovers available models on every startup.

## What It Filters

The plugin queries the Copilot API and whitelists only models where **both** conditions are true:

| Condition | Field | Required Value |
|-----------|-------|----------------|
| Enabled in model picker | `model_picker_enabled` | `true` |
| Chat-capable | `capabilities.type` | `"chat"` |

Models that are disabled by your organization admin, or that aren't chat models (e.g., embeddings, completions-only), are excluded from the picker.

**Before** (without plugin): All Copilot models shown — selecting a disabled one fails at runtime.

**After** (with plugin): Only your org-enabled chat models appear in the picker.

## Security

- The plugin reads your Copilot OAuth token from `~/.local/share/opencode/auth.json` (or `$XDG_DATA_HOME/opencode/auth.json`)
- The token is sent **only** to `api.githubcopilot.com` — the official GitHub Copilot API endpoint
- No tokens are logged, stored elsewhere, or sent to any third-party service
- The plugin has a 4-second request timeout and a 5-second overall timeout

## Troubleshooting

**Plugin doesn't seem to filter anything**
- Verify Copilot is authenticated: check that `~/.local/share/opencode/auth.json` contains a `github-copilot` entry with an `access` or `refresh` token
- The plugin fails silently by design — if the API call fails or times out, all models remain visible

**All models disappeared**
- This shouldn't happen — the plugin only sets a whitelist if it successfully discovers at least one enabled model
- Check if your Copilot subscription is active

**Plugin not loading**
- Confirm `"opencode-copilot-models"` is in the `plugin` array in `~/.config/opencode/opencode.json`
- Confirm the symlink exists: `ls -la ~/.cache/opencode/node_modules/opencode-copilot-models`
- Reinstall dependencies: `cd ~/.opencode/plugins/opencode-copilot-models && bun install`

## Development

```bash
bun install          # Install dependencies
# Edit src/index.ts, then restart OpenCode to test changes
```

The plugin uses TypeScript directly via Bun's native TS support — no build step required.

## License

[MIT](LICENSE)
