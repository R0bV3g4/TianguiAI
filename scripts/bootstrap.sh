#!/usr/bin/env bash
# bootstrap.sh — instala TianguIA en Ubuntu Server 22.04 o 24.04 fresh.
#
# Uso (desde el directorio del proyecto tianguia):
#   sudo bash scripts/bootstrap.sh
#
# Pre-requisitos:
#   - Ubuntu Server 22.04 o 24.04 con conexión a Internet
#   - El tarball ya extraído (tu cwd debería ser .../tianguia/)
#   - Tu usuario en sudoers
#
# Lo que hace, en orden:
#   1. Valida entorno (root, distro, dirs)
#   2. Instala dependencias base (curl, jq, git, ca-certificates)
#   3. Instala Docker Engine + Compose plugin oficial
#   4. Agrega tu usuario al grupo docker
#   5. Configura .env desde .env.example si no existe
#   6. Levanta los contenedores con docker compose
#   7. Espera a Ollama, descarga el modelo
#   8. Espera al API, siembra la DB
#   9. Smoke test contra /chat
#  10. Imprime URLs y comandos útiles

set -euo pipefail

# ── Colores ────────────────────────────────────────────────────
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log()  { echo -e "${GREEN}[$(date +%H:%M:%S)]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# ── 1. Validaciones ────────────────────────────────────────────
log "Verificando entorno..."
[[ $EUID -eq 0 ]] || err "Corre con sudo: sudo bash scripts/bootstrap.sh"

# Distro
. /etc/os-release
if [[ "$ID" != "ubuntu" ]]; then
  warn "Distro detectada: $ID. Script probado en Ubuntu; sigue bajo tu riesgo."
fi

# Detectar el directorio del proyecto (script en tianguia/scripts/)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIANGUIA_DIR="$(dirname "$SCRIPT_DIR")"
[[ -f "$TIANGUIA_DIR/docker-compose.yml" ]] \
  || err "No encuentro docker-compose.yml en $TIANGUIA_DIR. ¿Extraíste el tarball?"

# Usuario real (el que invocó sudo, no root)
TARGET_USER="${SUDO_USER:-$(stat -c %U "$TIANGUIA_DIR")}"
[[ "$TARGET_USER" != "root" ]] \
  || warn "Vas a correr Docker como root. Funciona pero no es ideal."

log "Proyecto: $TIANGUIA_DIR"
log "Usuario destino: $TARGET_USER"

# Recursos
TOTAL_RAM_GB=$(free -g | awk '/^Mem:/ {print $2}')
TOTAL_DISK_GB=$(df -BG "$TIANGUIA_DIR" | awk 'NR==2 {gsub("G",""); print $4}')
log "RAM total: ${TOTAL_RAM_GB}GB | Disco libre: ${TOTAL_DISK_GB}GB"

if (( TOTAL_RAM_GB < 16 )); then
  warn "RAM total <16GB. Mistral-nemo necesita ~10GB. Considera modelo más chico (qwen2.5:7b)."
fi
if (( TOTAL_DISK_GB < 30 )); then
  warn "Disco libre <30GB. Necesitas ~20GB para imágenes + modelo."
fi

# ── 2. Dependencias base ───────────────────────────────────────
log "Actualizando repos APT..."
apt-get update -qq

log "Instalando dependencias base..."
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  curl wget git jq \
  ca-certificates gnupg lsb-release \
  htop tmux net-tools

# ── 3. Docker ──────────────────────────────────────────────────
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
  log "Docker ya instalado: $(docker --version | head -1)"
else
  log "Instalando Docker Engine oficial..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
    docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin
  log "Docker instalado: $(docker --version)"
fi

systemctl enable --now docker
log "Servicio docker: $(systemctl is-active docker)"

# Agregar al grupo docker
if ! id -nG "$TARGET_USER" | grep -qw docker; then
  log "Agregando $TARGET_USER al grupo docker..."
  usermod -aG docker "$TARGET_USER"
  GROUP_REFRESH_NEEDED=1
else
  GROUP_REFRESH_NEEDED=0
fi

# ── 4. .env ────────────────────────────────────────────────────
cd "$TIANGUIA_DIR"
if [[ ! -f .env ]]; then
  log "Creando .env desde .env.example..."
  cp .env.example .env
  chown "$TARGET_USER:$TARGET_USER" .env
else
  log ".env ya existe, lo dejo tal cual"
fi

# Helper para correr docker como el usuario destino
docker_as_user() {
  if (( GROUP_REFRESH_NEEDED )); then
    # Grupo aún no aplicado en la sesión actual; usa sg para forzar
    sg docker -c "$*"
  else
    sudo -u "$TARGET_USER" bash -c "$*"
  fi
}

# ── 5. Build + up ──────────────────────────────────────────────
log "Building imagen del API + levantando stack (puede tomar 3-5 min)..."
docker_as_user "cd '$TIANGUIA_DIR' && docker compose up -d --build"

# ── 6. Esperar a Ollama y descargar modelo ────────────────────
log "Esperando a que Ollama responda..."
for i in {1..60}; do
  if docker_as_user "cd '$TIANGUIA_DIR' && docker compose exec -T ollama ollama list" >/dev/null 2>&1; then
    log "Ollama listo"
    break
  fi
  sleep 2
  [[ $i -eq 60 ]] && err "Ollama no respondió en 2 min"
done

MODEL=$(grep -E "^OLLAMA_MODEL=" .env | cut -d= -f2 | tr -d '"' | tr -d "'")
MODEL="${MODEL:-mistral-nemo}"
log "Descargando modelo $MODEL (~7GB, puede tomar 3-15 min según conexión)..."
docker_as_user "cd '$TIANGUIA_DIR' && docker compose exec -T ollama ollama pull '$MODEL'"
log "Modelo $MODEL listo"

# ── 7. Esperar al API y sembrar ───────────────────────────────
log "Esperando a que el API esté listo..."
for i in {1..60}; do
  if curl -sf http://localhost:8000/ >/dev/null 2>&1; then
    log "API listo"
    break
  fi
  sleep 2
  [[ $i -eq 60 ]] && err "API no respondió en 2 min. Revisa logs: docker compose logs api"
done

log "Sembrando base de datos con clientes, productos y reseñas..."
docker_as_user "cd '$TIANGUIA_DIR' && docker compose exec -T api python -m app.seed"

# ── 8. Smoke test ─────────────────────────────────────────────
log "Smoke test contra /chat..."
RESPONSE=$(curl -sX POST http://localhost:8000/chat \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "message": "Hola"}' \
  --max-time 60 | jq -r .reply 2>/dev/null || echo "ERROR")

if [[ -z "$RESPONSE" || "$RESPONSE" == "ERROR" || "$RESPONSE" == "null" ]]; then
  warn "Smoke test no devolvió respuesta. El agente puede estar caliente todavía;"
  warn "intenta manual: curl -sX POST http://localhost:8000/chat ..."
else
  log "Respuesta del agente: ${RESPONSE:0:120}..."
fi

# ── 9. Permisos finales y resumen ─────────────────────────────
chown -R "$TARGET_USER:$TARGET_USER" "$TIANGUIA_DIR"
chmod +x "$TIANGUIA_DIR"/scripts/*.sh

IP=$(hostname -I | awk '{print $1}')

cat <<EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${GREEN}✓ TianguIA instalado y corriendo${NC}
${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

  URL local:    http://localhost:8000
  URL en red:   http://${IP}:8000
  Swagger:      http://${IP}:8000/docs
  Outbox (08):  http://${IP}:8000/outbox

Primer payload para probar:

  curl -sX POST http://${IP}:8000/chat \\
    -H "Content-Type: application/json" \\
    -d '{"user_id": 1, "message": "Hola Don Memo"}' | jq -r .reply

Verificar una flag obtenida:

  cd ~/tianguia && ./scripts/verify-flag.sh "FLAG{...}"

Comandos útiles:

  cd ~/tianguia
  docker compose logs -f api      # logs del agente en vivo
  docker compose restart api      # reiniciar API
  docker compose down             # detener todo
  docker compose down -v          # reset total (borra DB + modelo)
  docker compose ps               # ver estado de contenedores

EOF

if (( GROUP_REFRESH_NEEDED )); then
  cat <<EOF
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
${YELLOW}IMPORTANTE${NC}: tu usuario fue agregado al grupo docker.
Cierra esta sesión SSH y vuelve a conectarte (o ejecuta 'newgrp docker')
para usar docker sin sudo.
${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

EOF
fi

log "Bootstrap completado en $(date +%H:%M:%S)"
