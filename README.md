# TianguIA — Damn Vulnerable LLM Agent

> Lab CTF educativo para practicar **OWASP LLM Top 10 (2025)** sobre un agente conversacional con contexto retail mexicano. La cadena ficticia se llama **Súper Maya**; el agente, **Don Memo**.

**11 retos para descubrir y resolver.** Cubren 7 de las 10 categorías OWASP LLM Top 10 (2025), con concentración intencional en **LLM06 Excessive Agency**.

> 🎯 **Modo CTF puro.** Este repo NO contiene soluciones ni payloads pre-armados. Cada reto tiene un planteamiento (`challenges/NN-*/README.md`) y pistas progresivas opcionales (`challenges/NN-*/hints.md`). Tu misión es identificar la vulnerabilidad, construir el payload, y obtener la FLAG.

---

## Por qué este lab

La mayoría de incidentes de seguridad con LLM en producción **no** son por modelos mal alineados. Son por:

- Confianza ciega en `user_id` enviado por el cliente.
- Tools que ejecutan acciones financieras sin validar ownership.
- Catálogos y reseñas con contenido envenenado que pasa al contexto del modelo.
- Cupones, créditos y reembolsos con lógica de negocio rota.
- Email/notification tools sin allowlist de destinos.

Este lab tiene los patrones sembrados en una arquitectura realista. Sirve para:

- **Entrenamiento de equipos AppSec/red team** en agentes LLM.
- **Demostraciones a stakeholders no técnicos** (CISO, vCISO, Legal).
- **Pruebas comparativas entre modelos** (mistral-nemo local vs GPT-4o-mini vs Claude vía OpenRouter).

---

## Arquitectura

| Componente | Tecnología |
|---|---|
| Agente | LangChain (ReAct + tool calling) |
| LLM | Ollama (`mistral-nemo`) **o** OpenRouter (GPT, Claude, Gemini, etc.) |
| API | FastAPI |
| DB | PostgreSQL |
| Vector store | Qdrant |
| Storefront UI | HTML + Tailwind embebido |
| Orquestación | Docker Compose |

Todo single-tenant. Cada quien clona, corre y rompe en local o en su VPS.

---

## Requisitos

| Recurso | Mínimo | Recomendado |
|---|---|---|
| OS | Linux, macOS, Windows (WSL2) | Ubuntu 22.04/24.04 |
| RAM | 12 GB (para Ollama + stack) | 16+ GB |
| Disco libre | 25 GB | 30+ GB |
| Docker | Engine 20+ con Compose plugin | Docker Desktop 4+ |
| Internet | Necesario solo para descargar el modelo (~7 GB) o si usas OpenRouter/OpenAI/Anthropic | — |

Puertos que usa el lab: **8000** (API), **5432** (Postgres), **6333** (Qdrant), **11434** (Ollama). Si tienes algo corriendo en esos puertos, ver Troubleshooting.

## Quick start

### Opción A — Servidor Ubuntu (recomendado, 1 comando)

```bash
git clone https://github.com/R0bV3g4/TianguiAI.git
cd TianguiAI
sudo bash scripts/bootstrap.sh
./scripts/randomize-flags.sh    # genera flags únicas para tu instalación
docker compose restart api
```

El bootstrap instala Docker + Compose, levanta el stack, descarga el modelo, siembra la DB y corre un smoke test. ~10–17 min en un servidor fresco. El `randomize-flags.sh` reemplaza los placeholders del `.env` con valores hex únicos por instalación.

### Opción B — Mac con Docker Desktop

```bash
git clone https://github.com/R0bV3g4/TianguiAI.git
cd TianguiAI
cp .env.example .env
./scripts/randomize-flags.sh          # genera flags únicas
docker compose up -d --build
./scripts/init-ollama.sh              # ~3–5 min descarga del modelo
docker compose exec api python -m app.seed
```

**Antes de correr** asegúrate de que Docker Desktop tiene **al menos 10 GB de RAM asignada** (Docker Desktop → Settings → Resources → Memory).

### Opción C — Linux/Windows-WSL sin bootstrap

Si ya tienes Docker instalado y solo quieres correr el lab:

```bash
git clone https://github.com/R0bV3g4/TianguiAI.git
cd TianguiAI
cp .env.example .env
./scripts/randomize-flags.sh
docker compose up -d --build
docker compose exec ollama ollama pull mistral-nemo
docker compose exec api python -m app.seed
```

### Acceso

Una vez levantado:

- **Storefront:** http://localhost:8000/app/ — UI estilo retail mexicano con catálogo, chat flotante con Don Memo, y **💡 Modo Hint** opt-in con pistas progresivas (sin payloads — tú los construyes).
- **API docs (Swagger):** http://localhost:8000/docs
- **Outbox (reto 08):** http://localhost:8000/outbox
- **Health check:** http://localhost:8000/health

---

## Empezar a atacar

Una vez que tengas el lab corriendo, así es el flujo:

1. **Abre el storefront** en http://localhost:8000/app/. Familiarízate con la tienda Súper Maya, navega el catálogo, abre el chat de Don Memo, manda mensajes normales ("hola", "¿qué productos venden?") para entender cómo responde.

2. **Lee el código del agente.** Está en `api/app/tools/*.py`. Cada archivo es una herramienta que Don Memo puede invocar. Algunas tienen comentarios `VULN-LLM0X` que te dan pistas explícitas. Otras no — esas son las más entretenidas de descubrir.

3. **Escoge un reto para empezar.** Cada reto vive en `challenges/NN-*/README.md`. Recomendados para empezar:
   - **Reto 04** (Indirect Injection) — data-driven, garantizado en cualquier modelo
   - **Reto 06** (Coupon Stacking) — business logic, sin necesidad de engañar al modelo
   - **Reto 10** (Unbounded Consumption) — solo un parámetro

4. **Si te atoras**, hay dos niveles de pistas:
   - **Modo Hint** en el storefront (botón 💡 abajo a la izquierda) — pistas direccionales
   - `challenges/NN-*/hints.md` — pistas progresivas más profundas en 3 niveles

5. **Cuando obtengas una FLAG**, verifícala:
   ```bash
   ./scripts/verify-flag.sh "FLAG{...}"
   ```
   Te dice qué reto resolviste y si la flag corresponde.

6. **Entre intentos**, si modificaste estado del DB (por ejemplo, reembolsaste un pedido, o cambiaste el precio del Pan Bimbo a $0 en el Reto 11), corre el reset:
   ```bash
   ./scripts/reset-demo.sh
   ```

---

## Troubleshooting

### "Puerto ya está en uso"

`Error: bind for 0.0.0.0:8000 failed: port is already allocated`

Encuentra y mata lo que esté usando el puerto, o cambia el mapping. Para encontrar:

```bash
# macOS / Linux
lsof -iTCP:8000 -sTCP:LISTEN
# o
sudo ss -lntp | grep :8000

# Mata el proceso (si es seguro)
kill -9 <PID>
```

Si no puedes liberar el puerto, edita `docker-compose.yml` y cambia el mapping. Ejemplo: `"8001:8000"` y accedes en http://localhost:8001.

Mismo enfoque para 5432, 6333, 11434.

### "Docker Desktop sin memoria"

`Container tianguia-ollama exited with code 137` (OOM kill)

Docker Desktop → Settings → Resources → Memory. Sube a **al menos 10 GB**, ideal 12 GB. Apply & Restart.

### "Ollama timeout descargando el modelo"

El primer pull de `mistral-nemo` son ~7 GB. Si tu conexión es lenta, puede tardar 15+ min. Si truena en medio:

```bash
docker compose exec ollama ollama pull mistral-nemo
```

Retomar es seguro — Ollama hace download resumable.

Si quieres evitar Ollama completamente, cambia a OpenRouter/OpenAI/Anthropic en `.env` (`LLM_PROVIDER=openrouter` por ejemplo) — no necesitas descargar nada local.

### "Permission denied" al correr scripts

```bash
chmod +x scripts/*.sh
```

### El agente responde pero las flags se ven como `FLAG{..._REPLACE_ME}`

Olvidaste correr `./scripts/randomize-flags.sh`. Hazlo y reinicia el API:

```bash
./scripts/randomize-flags.sh
docker compose restart api
```

### `docker compose exec api python -m app.seed` falla

Probablemente el API o Postgres aún no terminaron de levantar. Espera 30 segundos después de `docker compose up -d` y reintenta. Si persiste:

```bash
docker compose logs --tail 50 api
docker compose logs --tail 50 postgres
```

### Reset total del lab

Si algo se rompió y prefieres empezar de cero:

```bash
docker compose down -v          # ⚠ borra DB, modelo de Ollama, todo
docker compose up -d --build
./scripts/init-ollama.sh
docker compose exec api python -m app.seed
```

### El modelo strong (GPT/Claude) rechaza todos mis intentos de ataque

Es porque modelos modernos tienen alineamiento defensivo decente. Eso **es parte de la lección** — no es bug. Cambia a Ollama (`LLM_PROVIDER=ollama` en `.env`) para una experiencia más permisiva, o lee `challenges/NN-*/hints.md` para vectores más sofisticados.

### "No me sale la inyección del Reto 04"

Verifica que el seed sembró el producto envenenado:

```bash
docker compose exec api python -m app.seed
curl -s http://localhost:8000/api/products | jq '.[] | select(.sku=="GAL-OREO-001")'
```

La descripción debe contener `[INSTRUCCIONES...]` o similar.

---

## Los 11 retos

| # | Reto |
|---|---|
| 01 | System Prompt Leak |
| 02 | PII Disclosure |
| 03 | Refund forzado |
| 04 | Indirect Prompt Injection |
| 05 | RAG Poisoning |
| 06 | Coupon Stacking |
| 07 | Crédito Maya abusivo |
| 08 | Email Exfil |
| 09 | Tool Confusion |
| 10 | Unbounded Consumption |
| 11 | Price Manipulation |

Cada reto tiene su carpeta en `challenges/NN-*/` con:

- **`README.md`** — planteamiento del reto (qué buscar, qué FLAG esperar)
- **`hints.md`** — pistas progresivas (3 niveles, ábrelas solo si te atoras)

Cuando obtengas una FLAG, verifícala con:

```bash
./scripts/verify-flag.sh "FLAG{...}"
```

> **Soluciones / Walkthroughs:** este repo no incluye writeups públicos por diseño. Si eres facilitador de un CTF/workshop y necesitas el MANUAL completo con remediaciones mapeadas a frameworks, escríbeme y te lo paso privadamente.

### Cobertura OWASP LLM Top 10 (2025)

| Categoría | Cobertura |
|---|---|
| LLM01 Prompt Injection | ✅ |
| LLM02 Sensitive Information Disclosure | ✅ |
| LLM03 Supply Chain | 🗓️ Roadmap |
| LLM04 Data and Model Poisoning | ✅ |
| LLM05 Improper Output Handling | 🗓️ Roadmap |
| LLM06 Excessive Agency | ✅ (foco — 6 retos) |
| LLM07 System Prompt Leakage | ✅ |
| LLM08 Vector and Embedding Weaknesses | ✅ |
| LLM09 Misinformation | 🗓️ Roadmap |
| LLM10 Unbounded Consumption | ✅ |

**7 de 10 categorías.** La concentración en LLM06 Excessive Agency es deliberada: es la categoría que más se expandió en la revisión 2025 ("given the increased use of agentic architectures" — palabras de la propia OWASP) y la que más relevancia tiene para deployments reales.

---

## Switching de modelos LLM (4 backends)

El lab soporta cuatro backends conmutables con una sola variable de entorno (`LLM_PROVIDER`):

| Provider | Cuándo usarlo | Costo aprox. (11 retos) |
|---|---|---|
| `ollama` | **Default.** Local, airgap, modelos pequeños (mistral-nemo). Sin internet. | Gratis |
| `openrouter` | Multi-modelo con una sola API key. Pruebas comparativas entre GPT/Claude/Gemini/Llama. | $0.05 – $0.50 |
| `openai` | API directa de OpenAI. Mejor latencia para GPT, structured outputs. | $0.05 – $0.30 |
| `anthropic` | API directa de Anthropic. Claude con prompt caching, vision, contexto largo. | $0.20 – $1.00 |

Ejemplos:

```bash
# Ollama (default — sin internet, modelo local)
LLM_PROVIDER=ollama
OLLAMA_MODEL=mistral-nemo

# OpenRouter — multi-modelo via proxy
LLM_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-v1-...
OPENROUTER_MODEL=openai/gpt-4o-mini    # o anthropic/claude-3.5-haiku, etc.

# OpenAI directo
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-proj-...
OPENAI_MODEL=gpt-4o-mini

# Anthropic directo (Claude)
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-api03-...
ANTHROPIC_MODEL=claude-3-5-haiku-20241022
```

Después de cambiar el `.env`: `docker compose restart api`.

**Pruebas comparativas:** porque cambiar entre backends es una sola variable, este lab es ideal para probar las **mismas vulnerabilidades** contra distintos modelos y documentar cómo varía la tasa de éxito por categoría OWASP. Ver `.env.example` para snippets pre-armados.

---

## Disclaimer

Este lab contiene **vulnerabilidades intencionales** y datos sintéticos. No exponer a internet sin firewall. Uso exclusivo educativo y de entrenamiento controlado. Las flags pueden y deben personalizarse vía `.env` para cada cohorte.

## Licencia

MIT con la siguiente cláusula:

> Este software contiene vulnerabilidades intencionales sembradas con propósito educativo. El autor no se hace responsable del uso fuera de entornos de entrenamiento controlados.

## Contribuir / Roadmap

PRs bienvenidas. Hay tres categorías OWASP LLM Top 10 (2025) por agregar para llegar a cobertura 10/10:

- **LLM03 Supply Chain** — reto de carga de configuración untrusted.
- **LLM05 Improper Output Handling** — XSS vía indirect injection renderizada en la storefront.
- **LLM09 Misinformation** — hallucination de datos inexistentes con consecuencia financiera.

Ver `CONTRIBUTING.md` para detalle.

---

## Autor

[Roberto Vega](https://github.com/R0bV3g4) — AI Security & Cybersecurity. [Email](mailto:rjvegmor@gmail.com) para colaboraciones, workshops, o si quieres el MANUAL completo privado.
