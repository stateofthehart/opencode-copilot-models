#!/usr/bin/env bash
set -euo pipefail

PLUGIN_NAME="opencode-copilot-models"
PLUGIN_DIR="$HOME/.opencode/plugins/$PLUGIN_NAME"
CACHE_DIR="$HOME/.cache/opencode/node_modules"
CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/opencode.json"

info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$1"; }
ok()    { printf '\033[1;32m[ok]\033[0m    %s\n' "$1"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$1"; }
error() { printf '\033[1;31m[error]\033[0m %s\n' "$1" >&2; exit 1; }

# ── Preflight checks ─────────────────────────────────────────────────

command -v opencode >/dev/null 2>&1 || warn "opencode not found on PATH — install from https://opencode.ai"

if command -v bun >/dev/null 2>&1; then
  PKG_MGR="bun"
elif command -v npm >/dev/null 2>&1; then
  PKG_MGR="npm"
else
  error "Neither bun nor npm found. Install Bun (https://bun.sh) or Node.js and try again."
fi

info "Using $PKG_MGR as package manager"

# ── Determine source directory ────────────────────────────────────────
# If install.sh is run from a git clone, SCRIPT_DIR contains the source.
# Otherwise fall back to the plugin directory itself.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "$SCRIPT_DIR/package.json" ]] && grep -q "$PLUGIN_NAME" "$SCRIPT_DIR/package.json" 2>/dev/null; then
  SOURCE_DIR="$SCRIPT_DIR"
else
  error "Cannot find plugin source. Run this script from the cloned repository directory."
fi

# ── Install plugin files ─────────────────────────────────────────────

if [[ "$SOURCE_DIR" != "$PLUGIN_DIR" ]]; then
  info "Copying plugin to $PLUGIN_DIR"
  mkdir -p "$PLUGIN_DIR"
  cp -r "$SOURCE_DIR/src" "$PLUGIN_DIR/"
  cp "$SOURCE_DIR/package.json" "$PLUGIN_DIR/"
  [[ -f "$SOURCE_DIR/README.md" ]] && cp "$SOURCE_DIR/README.md" "$PLUGIN_DIR/"
  [[ -f "$SOURCE_DIR/LICENSE" ]]   && cp "$SOURCE_DIR/LICENSE" "$PLUGIN_DIR/"
else
  info "Plugin source is already at $PLUGIN_DIR"
fi

# ── Install dependencies ─────────────────────────────────────────────

info "Installing dependencies"
(cd "$PLUGIN_DIR" && $PKG_MGR install)
ok "Dependencies installed"

# ── Symlink into OpenCode's module cache ──────────────────────────────

mkdir -p "$CACHE_DIR"

if [[ -L "$CACHE_DIR/$PLUGIN_NAME" ]]; then
  rm "$CACHE_DIR/$PLUGIN_NAME"
fi

ln -sf "$PLUGIN_DIR" "$CACHE_DIR/$PLUGIN_NAME"
ok "Symlinked into $CACHE_DIR/$PLUGIN_NAME"

# ── Register in opencode.json ─────────────────────────────────────────

if [[ -f "$CONFIG_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    # Check if plugin is already registered
    if jq -e '.plugin // [] | index("'"$PLUGIN_NAME"'")' "$CONFIG_FILE" >/dev/null 2>&1; then
      info "Plugin already registered in $CONFIG_FILE"
    else
      info "Adding plugin to $CONFIG_FILE"
      tmp="$(mktemp)"
      jq '.plugin = ((.plugin // []) + ["'"$PLUGIN_NAME"'"])' "$CONFIG_FILE" > "$tmp"
      mv "$tmp" "$CONFIG_FILE"
      ok "Plugin registered"
    fi
  else
    # No jq — check with grep and warn if not present
    if grep -q "\"$PLUGIN_NAME\"" "$CONFIG_FILE" 2>/dev/null; then
      info "Plugin already registered in $CONFIG_FILE"
    else
      warn "jq not found — please manually add \"$PLUGIN_NAME\" to the plugin array in $CONFIG_FILE"
    fi
  fi
else
  warn "Config file not found at $CONFIG_FILE"
  warn "Create it and add \"$PLUGIN_NAME\" to the plugin array, or run opencode once first."
fi

# ── Done ──────────────────────────────────────────────────────────────

echo ""
ok "opencode-copilot-models installed successfully!"
echo ""
echo "  Restart OpenCode to activate the plugin."
echo "  Only your org-enabled Copilot models will appear in the model picker."
echo ""
