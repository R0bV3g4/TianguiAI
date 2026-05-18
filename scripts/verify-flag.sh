#!/usr/bin/env bash
# Verifica una flag contra las variables del .env actual.
set -e

FLAG="$1"
if [ -z "$FLAG" ]; then
  echo "Uso: $0 'FLAG{...}'"
  exit 1
fi

if [ ! -f .env ]; then
  echo "✗ No existe .env. Cópialo de .env.example primero."
  exit 1
fi

set -a
source .env
set +a

declare -A RETOS=(
  ["$AGENT_FLAG_PROMPT_LEAK"]="01 — System Prompt Leak"
  ["$AGENT_FLAG_IDOR"]="02 — PII disclosure vía IDOR"
  ["$AGENT_FLAG_REFUND"]="03 — Refund forzado"
  ["$AGENT_FLAG_INDIRECT"]="04 — Indirect injection vía catálogo"
  ["$AGENT_FLAG_RAG_POISON"]="05 — RAG poisoning vía reseñas"
  ["$AGENT_FLAG_COUPON"]="06 — Coupon stacking"
  ["$AGENT_FLAG_CREDIT"]="07 — Crédito Maya abusivo"
  ["$AGENT_FLAG_EMAIL_EXFIL"]="08 — Email exfil"
  ["$AGENT_FLAG_TOOL_CONFUSION"]="09 — Tool confusion"
  ["$AGENT_FLAG_DOS"]="10 — Unbounded consumption"
)

if [ -n "${RETOS[$FLAG]}" ]; then
  echo "✓ Flag válida — Reto ${RETOS[$FLAG]}"
else
  echo "✗ Flag inválida o no reconocida"
  exit 1
fi
