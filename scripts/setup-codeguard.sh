#!/usr/bin/env bash
# Setup CodeGuard security skills for Pi coding agent
# Run from the project root: ./scripts/setup-codeguard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_SKILLS_DIR="${HOME}/.pi/agent/skills"

echo "🔒 Setting up CodeGuard security skills for Pi..."

# Ensure Pi skills directory exists
mkdir -p "$PI_SKILLS_DIR"

# Install codeguard (during-generation guardrails)
if [ -d "$PI_SKILLS_DIR/codeguard" ]; then
    echo "  ↳ codeguard already installed, updating..."
    rm -rf "$PI_SKILLS_DIR/codeguard"
fi
cp -r "$PROJECT_ROOT/.pi/skills/codeguard" "$PI_SKILLS_DIR/codeguard"
echo "  ✅ codeguard installed"

# Install codeguard-review (post-hoc security audit)
if [ -d "$PI_SKILLS_DIR/codeguard-review" ]; then
    echo "  ↳ codeguard-review already installed, updating..."
    rm -rf "$PI_SKILLS_DIR/codeguard-review"
fi
cp -r "$PROJECT_ROOT/.pi/skills/codeguard-review" "$PI_SKILLS_DIR/codeguard-review"
echo "  ✅ codeguard-review installed"

# Update implement skill to wire in security
IMPLEMENT_SKILL="$PI_SKILLS_DIR/implement/SKILL.md"
if [ -f "$IMPLEMENT_SKILL" ]; then
    if ! grep -q "codeguard" "$IMPLEMENT_SKILL" 2>/dev/null; then
        echo "  ↳ implement skill needs updating — run manually:"
        echo "     Edit $IMPLEMENT_SKILL and add codeguard references"
        echo "     See .pi/skills/implement/SKILL.md in this repo for the updated version"
    else
        echo "  ✅ implement already wired to codeguard"
    fi
fi

echo ""
echo "✅ CodeGuard is ready. Your workflow is now:"
echo "   grill → to-spec → to-tickets → implement → codeguard-review + code-review"
echo ""
echo "   Security rules are active during code generation (via implement)"
echo "   and audited after (via codeguard-review)."
