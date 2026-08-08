#!/usr/bin/env bash
# Setup agentic workflow skills for Pi coding agent
# Run from the project root: ./scripts/setup-codeguard.sh
#
# Installs:
#   - tdd                — test-driven development (red-green-refactor)
#   - codeguard          — security guardrails during code generation
#   - codeguard-review   — security audit of diffs (23 rules)
#   - eval-ai-output     — 4-gate validation (Functional, Logical, Quality, Hallucination)
#   - implement          — updated implement flow (wired to all five skills)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PI_SKILLS_DIR="${HOME}/.pi/agent/skills"

echo "🔒 Setting up agentic workflow skills for Pi..."
echo ""

# Ensure Pi skills directory exists
mkdir -p "$PI_SKILLS_DIR"

# ── Install skills ──────────────────────────────────────────────

install_skill() {
    local name="$1"
    local emoji="$2"
    if [ -d "$PI_SKILLS_DIR/$name" ]; then
        echo "  ↳ $name already installed, updating..."
        rm -rf "$PI_SKILLS_DIR/$name"
    fi
    cp -r "$PROJECT_ROOT/.pi/skills/$name" "$PI_SKILLS_DIR/$name"
    echo "  $emoji $name installed"
}

install_skill "tdd"                "🧪"
install_skill "codeguard"          "🔒"
install_skill "codeguard-review"   "🛡️"
install_skill "eval-ai-output"     "✅"

# ── Install updated implement skill ─────────────────────────────

echo ""
echo "  ↳ Updating implement skill..."
if [ -d "$PI_SKILLS_DIR/implement" ]; then
    rm -rf "$PI_SKILLS_DIR/implement"
fi
cp -r "$PROJECT_ROOT/.pi/skills/implement" "$PI_SKILLS_DIR/implement"
echo "  ⚙️  implement installed (wired to tdd + codeguard + eval-ai-output + codeguard-review)"

# ── Done ────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✅ All skills installed. Your workflow:"
echo ""
echo "  grill → to-spec → to-tickets → implement"
echo "                                  │"
echo "       ┌──────────────────────────┘"
echo "       │"
echo "       ├─ /codeguard (security context)"
echo "       ├─ /tdd (test → red → code → green)"
echo "       ├─ /eval-ai-output (4-gate check)"
echo "       ├─ /codeguard-review (23-rule security audit)"
echo "       └─ /code-review (standards + spec)"
echo ""
echo "  Run '/implement' — everything is wired in automatically."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
