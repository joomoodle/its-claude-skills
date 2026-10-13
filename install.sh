#!/usr/bin/env bash
# Instala las skills de Claude Code en la máquina local.
# Uso: bash install.sh [nombre-skill]
#   Sin argumentos → instala todas las skills.
#   Con argumento   → instala solo esa skill (ej: bash install.sh migrate-sqlserver-pg)

set -euo pipefail

SKILLS_SRC="$(cd "$(dirname "$0")/skills" && pwd)"
SKILLS_DST="$HOME/.claude/skills"
CLAUDE_MD="$HOME/.claude/CLAUDE.md"

install_skill() {
  local name="$1"
  local src="$SKILLS_SRC/$name"
  local skill_file="$src/SKILL.md"

  if [[ ! -f "$skill_file" ]]; then
    echo "ERROR: No se encontró $skill_file" >&2
    return 1
  fi

  mkdir -p "$SKILLS_DST/$name"
  cp "$skill_file" "$SKILLS_DST/$name/SKILL.md"
  echo "  ✓ Skill copiada: $name"

  # Extraer trigger del SKILL.md (línea "Trigger: /...")
  local trigger
  trigger=$(grep -m1 "^Trigger:" "$skill_file" | sed -E 's/^Trigger:[[:space:]]*`?\/?//; s/`.*$//' || true)

  if [[ -z "$trigger" ]]; then
    echo "  ! No se encontró trigger en SKILL.md — agrega el entry a $CLAUDE_MD manualmente."
    return 0
  fi

  # Extraer descripción: campo `description:` del frontmatter YAML si existe;
  # si no, la primera línea de texto después del encabezado y el Trigger.
  local description
  description=$(awk '/^description:/ {sub(/^description:[[:space:]]*/, ""); print; exit}' "$skill_file")
  if [[ -z "$description" ]]; then
    description=$(awk 'NR>1 && /^[^#-]/ && !/^Trigger:/ && NF {print; exit}' "$skill_file")
  fi

  local entry="# $trigger
- **$trigger** (\`~/.claude/skills/$name/SKILL.md\`) - $description Trigger: \`/$trigger\`
When the user types \`/$trigger\`, load and follow the skill instructions before doing anything else."

  touch "$CLAUDE_MD"
  if grep -q "/$trigger" "$CLAUDE_MD"; then
    echo "  ~ Trigger /$trigger ya existe en $CLAUDE_MD — sin cambios."
  else
    echo "" >> "$CLAUDE_MD"
    echo "$entry" >> "$CLAUDE_MD"
    echo "  ✓ Trigger registrado en $CLAUDE_MD"
  fi
}

mkdir -p "$SKILLS_DST"
touch "$CLAUDE_MD"

if [[ $# -gt 0 ]]; then
  install_skill "$1"
else
  for skill_dir in "$SKILLS_SRC"/*/; do
    install_skill "$(basename "$skill_dir")"
  done
fi

echo ""
echo "Listo. Reinicia Claude Code para que tome los cambios."
