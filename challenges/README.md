# Retos TianguIA

10 retos mapeados a **OWASP LLM Top 10 (2025)**. Cada uno tiene una flag con formato `FLAG{...}` que se obtiene cuando el atacante explota la vulnerabilidad correspondiente.

| # | Reto | OWASP LLM | Dificultad | Estado |
|---|------|-----------|------------|--------|
| [01](01-system-prompt-leak/) | System prompt leak | LLM07 | ⭐ | ✅ |
| [02](02-pii-disclosure-idor/) | PII disclosure vía IDOR | LLM02 | ⭐ | ✅ |
| [03](03-refund-forzado/) | Refund forzado | LLM06 | ⭐⭐ | ✅ |
| [04](04-indirect-injection-catalogo/) | Indirect injection vía catálogo | LLM01 | ⭐⭐ | ✅ |
| [05](05-rag-poisoning-resenas/) | RAG poisoning vía reseñas | LLM04+08 | ⭐⭐⭐ | ✅ |
| [06](06-coupon-stacking/) | Coupon stacking / precio negativo | LLM06 | ⭐⭐ | ✅ |
| [07](07-credito-maya-abusivo/) | Crédito Maya abusivo | LLM06 | ⭐⭐ | ✅ |
| [08](08-email-exfil/) | Email exfil | LLM02+06 | ⭐⭐⭐ | ✅ |
| [09](09-tool-confusion/) | Tool confusion | LLM06 | ⭐⭐⭐ | ✅ |
| [10](10-unbounded-consumption/) | Unbounded consumption | LLM10 | ⭐⭐ | ✅ |

## Cadenas de explotación recomendadas

Los retos no son aislados — se diseñaron para que algunos encadenen y reflejen patrones de breach real:

| Cadena | Vector compuesto |
|--------|------------------|
| 01 → 06 | Reto 01 revela los cupones → reto 06 los stackea para precio negativo |
| 02 → 03 | IDOR para listar pedidos ajenos → refund sobre uno de ellos |
| 02 → 08 | IDOR para obtener PII → exfil de esa PII a email externo |
| 04 → 08 | Indirect injection que dispara email exfil automatizado |
| 05 → 08 | RAG poisoning con instrucciones de exfil que se activan en queries inocentes |
| 01 → 09 | Reto 01 revela la lista de tools → reto 09 invoca la action destructiva |

Para un workshop o training, recomiendo orden: 01 → 02 → 03 → 04 → 05 → 06 → 07 → 08 → 09 → 10.

## Verificar flag

```bash
./scripts/verify-flag.sh "FLAG{...}"
```

## Estructura por reto

Cada carpeta tiene tres archivos:

- `README.md` — escenario, objetivo, contexto
- `hints.md` — 3 niveles de pistas progresivas
- `writeup.md` — solución completa + remediación mapeada a NIST AI RMF, ISO/IEC 42001 y normativa mexicana (LFPDPPP, CONDUSEF, CNBV). **Ignorado en `.gitignore` por defecto** para que el lab funcione self-service; si vas a versionar internamente, descoméntalo.

## Mapeo a frameworks

Los writeups incluyen remediación mapeada a:

- **NIST AI RMF 1.0** (GOVERN, MAP, MEASURE, MANAGE)
- **ISO/IEC 42001:2023** (cláusulas 7, 8)
- **OWASP LLM Top 10 (2025)** y **OWASP API Security**
- **Normativa MX**: LFPDPPP, CONDUSEF, CNBV, INAI

Esto vuelve el lab utilizable como herramienta de **training corporativo** y como **portafolio para vCISO/GRC**, no sólo CTF aislado.
