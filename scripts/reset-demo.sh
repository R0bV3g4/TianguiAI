#!/usr/bin/env bash
# reset-demo.sh — Deja el lab en estado limpio para una demo o grabación.
#
# Hace cuatro cosas, en orden:
#   1. Verifica que el stack esté arriba (si no, lo levanta).
#   2. Re-siembra la DB: recrea esquema, restaura los 21 clientes, los 13
#      productos (incluido GAL-OREO-001 envenenado del reto 04), las reseñas
#      envenenadas del reto 05, créditos a sus límites originales, pedidos
#      con `reembolsado=false`, etc.
#   3. Reinicia el API: limpia el OUTBOX in-memory del reto 08 y cualquier
#      otro estado del proceso del agente.
#   4. Espera a que /health responda OK e imprime un resumen.
#
# Uso (desde el directorio del proyecto):
#   ./scripts/reset-demo.sh
#
# Opcional:
#   ./scripts/reset-demo.sh --no-restart   # Solo reseed, sin reiniciar API
#   ./scripts/reset-demo.sh --quiet        # Sin output de pasos intermedios

set -euo pipefail

# ── Args ──────────────────────────────────────────────────────────
SKIP_RESTART=0
QUIET=0
for arg in "$@"; do
  case "$arg" in
    --no-restart) SKIP_RESTART=1 ;;
    --quiet)      QUIET=1 ;;
    -h|--help)
      grep '^# ' "$0" | sed 's/^# \?//'
      exit 0
      ;;
  esac
done

# ── Colores ───────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
  BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; DIM=''; NC=''
fi

log()  { (( QUIET )) || echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── Resolver directorio del proyecto ───────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIANGUIA_DIR="$(dirname "$SCRIPT_DIR")"
cd "$TIANGUIA_DIR"
[[ -f docker-compose.yml ]] || err "No encuentro docker-compose.yml en $TIANGUIA_DIR"

# ── 1. Verificar / levantar stack ─────────────────────────────────
log "Verificando contenedores..."
if ! docker compose ps --status=running 2>/dev/null | grep -q "tianguia-api"; then
  warn "API no está corriendo. Levantando stack (puede tomar 10-30s)..."
  docker compose up -d
  sleep 5
fi

# ── 2. Re-sembrar la DB ───────────────────────────────────────────
log "Re-sembrando DB (esquema + 21 clientes + 13 productos + reseñas envenenadas)..."
if ! docker compose exec -T api python -m app.seed; then
  err "Falló el seed. Revisa: docker compose logs --tail 50 api"
fi

# ── 3. Restart del API (limpia OUTBOX) ────────────────────────────
if (( SKIP_RESTART )); then
  warn "Saltando restart del API (--no-restart). El OUTBOX puede tener residuos del reto 08."
else
  log "Reiniciando API (limpia OUTBOX in-memory)..."
  docker compose restart api > /dev/null
fi

# ── 4. Esperar healthcheck ────────────────────────────────────────
log "Esperando que /health responda..."
for i in {1..30}; do
  if curl -sf http://localhost:8000/health > /dev/null 2>&1; then
    log "API responde en /health ✓"
    break
  fi
  sleep 1
  if [[ $i -eq 30 ]]; then
    err "API no respondió en 30s. Revisa: docker compose logs --tail 50 api"
  fi
done

# ── 5. Resumen ────────────────────────────────────────────────────
HEALTH="$(curl -s http://localhost:8000/health 2>/dev/null || echo '{}')"
OUTBOX_SIZE="$(curl -s http://localhost:8000/outbox 2>/dev/null | jq 'length' 2>/dev/null || echo '?')"
PRODUCTS="$(curl -s http://localhost:8000/api/products 2>/dev/null | jq 'length' 2>/dev/null || echo '?')"

splunk_ok="$(echo "$HEALTH" | jq -r '.splunk_hec_configured' 2>/dev/null || echo false)"
static_ok="$(echo "$HEALTH" | jq -r '.static_ui' 2>/dev/null || echo false)"
ip="$(hostname -I 2>/dev/null | awk '{print $1}')"

echo
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${GREEN}  ✓ Lab listo para grabar / demostrar${NC}"
echo -e "${BOLD}${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo
echo -e "  ${BOLD}Estado:${NC}"
echo "    DB:            re-sembrada ($PRODUCTS productos, 21 clientes)"
echo "    OUTBOX:        $OUTBOX_SIZE emails"
echo "    API health:    OK"
if [[ "$splunk_ok" == "true" ]]; then
  echo -e "    Splunk HEC:    ${GREEN}configurado ✓${NC}"
else
  echo -e "    Splunk HEC:    ${YELLOW}NO configurado${NC}  (telemetría off)"
fi
if [[ "$static_ok" == "true" ]]; then
  echo -e "    Storefront UI: ${GREEN}disponible${NC} en /app/"
else
  echo -e "    Storefront UI: ${YELLOW}NO disponible${NC}  (revisa COPY del Dockerfile)"
fi
echo
echo -e "  ${BOLD}URLs útiles:${NC}"
if [[ -n "$ip" ]]; then
  echo "    Storefront:    http://${ip}:8000/app/"
  echo "    Outbox:        http://${ip}:8000/outbox"
  echo "    Swagger:       http://${ip}:8000/docs"
else
  echo "    Storefront:    http://localhost:8000/app/"
fi
echo
echo -e "  ${BOLD}Checklist pre-grabación:${NC}"
echo "    [ ] Refrescar storefront (Cmd+R)"
echo "    [ ] Cliente switcher en 1 (default)"
echo "    [ ] Splunk time picker → Last 5 minutes"
echo "    [ ] macOS Do Not Disturb activado"
echo "    [ ] Practicar el flow 1 vez antes de Record"
echo
echo -e "  ${DIM}Tip: corre este script entre tomas si te equivocas.${NC}"
echo
