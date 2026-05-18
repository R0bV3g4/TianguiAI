#!/usr/bin/env bash
# randomize-flags.sh — Reemplaza los placeholders _REPLACE_ME del .env
# con sufijos hexadecimales aleatorios únicos por cada flag.
#
# Uso:
#   ./scripts/randomize-flags.sh [--env PATH]
#
# Default: edita el .env del directorio padre (~/tianguia/.env si el
# script vive en ~/tianguia/scripts/).
#
# Después de correr esto, reinicia el API para que tome las nuevas flags:
#   docker compose restart api
#
# IMPORTANTE: corre esto UNA SOLA VEZ por instalación. Si lo corres dos
# veces sin reset del lab, las flags cambian pero los retos ya resueltos
# no validan con verify-flag.sh contra los nuevos valores.

set -euo pipefail

# ── Resolver ENV path ─────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_PATH="$(dirname "$SCRIPT_DIR")/.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env) ENV_PATH="$2"; shift 2 ;;
    -h|--help) grep '^# ' "$0" | sed 's/^# \?//'; exit 0 ;;
    *) echo "Argumento desconocido: $1"; exit 1 ;;
  esac
done

# ── Colores ───────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  G='\033[0;32m'; Y='\033[1;33m'; R='\033[0;31m'; B='\033[1m'; N='\033[0m'
else
  G=''; Y=''; R=''; B=''; N=''
fi

# ── Validaciones ──────────────────────────────────────────────────
if [[ ! -f "$ENV_PATH" ]]; then
  echo -e "${R}[ERROR]${N} No encuentro $ENV_PATH"
  echo "  ¿Olvidaste hacer 'cp .env.example .env'?"
  exit 1
fi

# Detecta openssl (Linux/Mac lo tienen por default)
if ! command -v openssl >/dev/null 2>&1; then
  echo -e "${R}[ERROR]${N} openssl no está instalado. Es necesario para generar valores aleatorios."
  exit 1
fi

# Cuenta los REPLACE_ME que hay
COUNT="$(grep -c "REPLACE_ME" "$ENV_PATH" 2>/dev/null || echo 0)"
if [[ "$COUNT" == "0" ]]; then
  echo -e "${Y}[WARN]${N} No encontré ningún 'REPLACE_ME' en $ENV_PATH."
  echo "  Las flags ya están randomizadas, o el .env usa otros valores."
  exit 0
fi

echo -e "${B}Randomizando $COUNT flags en $ENV_PATH...${N}"

# ── Backup ────────────────────────────────────────────────────────
BACKUP="$ENV_PATH.bak-$(date +%Y%m%d-%H%M%S)"
cp "$ENV_PATH" "$BACKUP"
echo "  Backup: $BACKUP"

# ── sed cross-platform helper (macOS vs Linux) ────────────────────
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(sed -i)
else
  SED_INPLACE=(sed -i '')
fi

# ── Reemplaza cada REPLACE_ME con un hex aleatorio único ──────────
# Procesamos línea por línea para que cada FLAG tenga su propio sufijo
TMP="$(mktemp)"
while IFS= read -r line; do
  if [[ "$line" == *"REPLACE_ME"* ]]; then
    rand="$(openssl rand -hex 3)"
    line="${line//REPLACE_ME/$rand}"
  fi
  printf '%s\n' "$line" >> "$TMP"
done < "$ENV_PATH"
mv "$TMP" "$ENV_PATH"

# ── Verificación ──────────────────────────────────────────────────
REMAINING="$(grep -c "REPLACE_ME" "$ENV_PATH" 2>/dev/null || echo 0)"
if [[ "$REMAINING" != "0" ]]; then
  echo -e "${R}[ERROR]${N} Quedaron $REMAINING placeholders. Revisa $ENV_PATH"
  exit 1
fi

echo -e "${G}✓ Listo${N}. Tu .env ahora tiene flags únicas. Ejemplos:"
grep "^AGENT_FLAG_" "$ENV_PATH" | head -3 | sed 's|^|    |'
echo
echo -e "${B}Siguiente paso:${N} reinicia el API para que tome las nuevas flags:"
echo "    docker compose restart api"
