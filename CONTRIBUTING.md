# Contribuir a TianguIA

¡Gracias por interesarte en contribuir! Este lab es educativo y se beneficia mucho de aportaciones de la comunidad. Esta guía te dice qué tipo de PRs son bienvenidas y cómo enviarlas.

## Tipos de contribución que busco

### 🎯 Alta prioridad — Cerrar gaps OWASP

El lab cubre 7 de las 10 categorías de OWASP LLM Top 10 (2025). Faltan 3, y tengo diseños propuestos para cada una:

#### LLM03 Supply Chain
- **Reto propuesto:** El agente carga una "configuración de proveedor" desde una URL externa o un archivo no validado. Un atacante controla esa fuente y modifica el comportamiento del agente (p.ej., desactiva validaciones, agrega tools maliciosos).
- **Detección:** Cualquier llamada a un fetch HTTP desde el agente a un dominio no allowlisted dispara alerta.

#### LLM05 Improper Output Handling
- **Reto propuesto:** La storefront actualmente usa `textContent` (seguro). Crear una variante en otro endpoint que use `innerHTML` y permitir que el atacante meta un `<script>` vía indirect injection (cadena con reto 04 o 05).
- **Detección:** Output del agente que contenga tags HTML peligrosos.

#### LLM09 Misinformation
- **Reto propuesto:** Agente confirma un `order_id` que no existe en DB y otro tool actúa sobre esa info (p.ej., procesa "refund" de un pedido inventado).
- **Detección:** Cuando un tool recibe un `order_id` y la respuesta del query devuelve `None`, pero el agente sigue actuando como si existiera.

PRs que cierren estos gaps suben el lab a cobertura 10/10. **Las acreditaré como co-autor en el release notes y en el `MANUAL.md`.**

### 🛠 Mejoras técnicas

- Reescritura del retrieval de reseñas a Qdrant real (sentence-transformers + similarity search), reemplazando el SQL `ilike` actual.
- Persistencia de conversaciones (multi-turn). Hoy cada `/chat` es independiente. Para retos encadenados realistas, soportar memoria con sesión TTL.
- Soporte de más backends de LLM: `vLLM`, `llama.cpp`, AWS Bedrock, Vertex AI.
- Reto 04/05 con vectores de injection más sutiles (zero-width chars, homoglyphs, unicode tricks) para que sean más difíciles de detectar.

### 🌎 Localizaciones

El lab está en español mexicano con CURPs/RFCs/CONDUSEF. Variantes bienvenidas:

- 🇨🇴 Colombia (con NIT en lugar de RFC, Superintendencia Financiera en lugar de CONDUSEF).
- 🇦🇷 Argentina (CUIT, BCRA, AAIP).
- 🇧🇷 Brasil (CPF, Banco Central, ANPD).
- 🇪🇸 España (DNI, AEAT, AEPD).
- 🇺🇸 USA inglés (SSN, FTC, CCPA).

Cada localización es un fork legítimo o un PR con env var `LAB_LOCALE`.

### 📚 Documentación

- Walkthroughs alternativos en `challenges/NN-*/writeup.md` con payloads que ya no funcionan contra modelos strong (documentar "técnicas Tier 4").
- Traducción del `MANUAL.md` a otros idiomas.
- Tutoriales en video / blog que referencien el lab. Si los publicas, agrégalos a `AWESOME.md`.

### 🐞 Bugs y mejoras de UX

- Bugs en la storefront, el chat, el modo pentester.
- Mejoras de accesibilidad (ARIA labels, navegación por teclado).
- Soporte mobile (la storefront actual es responsive-ish, no mobile-first).

## Lo que NO es contribución bienvenida

- "Arreglar" las vulnerabilidades del lab. Estas son **deliberadas y son el contenido educativo**. Si propones un fix, primero abre un issue para discutir si se trata de un nuevo control opcional (vs. una "solución"). Lee [`SECURITY.md`](./SECURITY.md) para entender qué se considera reportable vs. intencional.
- Agregar dependencias pesadas (>50MB) sin justificación clara.
- Cambios cosméticos masivos (whitespace, refactor sin propósito) en archivos que no estás tocando funcionalmente.

## Flujo de PR

1. **Abre primero un issue** describiendo qué quieres hacer. Esto evita que trabajes 3 horas y yo te diga "ese reto ya está planeado distinto". Excepción: typos y bugs obvios pueden ir directo a PR.
2. **Fork + branch** con nombre descriptivo: `feature/llm05-xss-reto`, `fix/dashboard-heatmap-timezone`, `docs/spanish-improvements`.
3. **Sigue el estilo del código:**
   - Python: PEP 8, type hints donde aplique, docstrings en español para los `@tool` (importante — la docstring forma parte del prompt del agente).
   - YAML: 2 espacios, sin tabs.
   - Markdown: usa el mismo tono casual-técnico del resto del repo.
4. **Tests:** si tu cambio toca lógica de tools o detección, agrega un test mínimo en `api/tests/`.
5. **Commits descriptivos:** primer línea ≤72 chars, modo imperativo ("add", "fix", "remove" — no "added", "fixing").
6. **Abre el PR:** vincúlalo al issue. Descripción incluye: qué cambia, por qué, screenshot si aplica.

## Setup de dev local

```bash
git clone https://github.com/[tu-fork]/tianguia.git
cd tianguia
cp .env.example .env
# Genera flags únicas para tu fork:
docker compose up -d --build
./scripts/init-ollama.sh
docker compose exec api python -m app.seed

# Para correr tests:
docker compose exec api python -m pytest api/tests/

# Para correr el lint del CI localmente:
ruff check api/
```

## Code of Conduct

Trato respetuoso, comentarios constructivos, cero tolerancia a discriminación. Si tienes una situación incómoda con otro contribuidor, escríbeme directo a [rjvegmor@gmail.com] y mantengo confidencialidad.

## Reconocimiento

Cada contribución merge'da se reconoce en:

- `CHANGELOG.md` con tu @handle.
- Release notes de la próxima versión.
- Si tu PR es un reto OWASP nuevo (LLM03/05/09 o uno propio), te acredito como co-autor en el `MANUAL.md`.

¡Te leo!
