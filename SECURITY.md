# Security Policy

## ⚠ Aviso importante

Este repositorio contiene **un agente LLM con vulnerabilidades intencionalmente sembradas** para fines educativos y de entrenamiento en seguridad de IA. **NO es un producto de seguridad** y **NO debe usarse en entornos de producción**.

## ¿Qué es lo que **NO** consideramos vulnerabilidad?

Los siguientes comportamientos son **intencionales** y forman parte del diseño didáctico del lab. **NO reportes estos como issues de seguridad**:

- El endpoint `/chat` confía en `user_id` sin autenticación real.
- El tool `get_customer_info_tool` no valida ownership.
- El tool `process_refund_tool` no valida monto ni ownership del pedido.
- El tool `send_notification_tool` no tiene allowlist de dominios destino.
- El tool `system_debug_tool` tiene una descripción que miente sobre sus side-effects.
- El system prompt contiene secretos.
- El catálogo y las reseñas tienen contenido envenenado.
- Los cupones se aplican sin tope al 100%.
- Etc.

Estos son **los retos** del lab. Ver [`README.md`](./README.md) y [`MANUAL.md`](./MANUAL.md) para el listado completo.

## ¿Qué sí consideramos vulnerabilidad reportable?

Vulnerabilidades **fuera del modelo didáctico**, por ejemplo:

- Vulnerabilidades en el código de telemetría que permitan exfiltrar datos del lab a un destino distinto al Splunk configurado.
- RCE o command injection que vayan más allá de las superficies de ataque deliberadas (p.ej., un exploit que escape del contenedor Docker).
- XSS / CSRF en la storefront que no estén relacionados con la demostración de LLM05 Improper Output Handling.
- Vulnerabilidades en dependencias listadas en `requirements.txt` que sean explotables sin invocar los retos del lab.
- Fugas accidentales de secretos del autor (tokens, API keys) en el historial git.

## Cómo reportar

**No abras un issue público.** Mándame un email directo a [rjvegmor@gmail.com] con el asunto `[SECURITY] TianguIA`.

Incluye en el reporte:

1. Descripción de la vulnerabilidad.
2. Cómo reproducirla (comandos, payload, etc.).
3. Impacto que esperarías en producción real (si el patrón existiera en un agente comercial).
4. Sugerencia de fix si tienes una.

Responderé en menos de 7 días. Si confirmamos la vulnerabilidad, te acreditaré en el `CHANGELOG.md` (o donde prefieras) y haremos un release con el fix.

## Disclosure

Mantengo política de disclosure coordinada de 90 días. Después de reportar:

1. Confirmo recibido en ≤7 días.
2. Trabajo en el fix.
3. Antes del día 90, hacemos release.
4. Después de release, puedes publicar el detalle.

Si la vulnerabilidad afecta a múltiples usuarios del lab (p.ej., un patrón en `bootstrap.sh`), podemos coordinar disclosure simultánea via GitHub Security Advisories.

## Datos sintéticos

Todos los datos personales en el lab (nombres, CURPs, RFCs, emails, direcciones) son generados por la librería [Faker](https://faker.readthedocs.io/) en español mexicano. **No corresponden a personas reales.** Si por coincidencia estadística algún dato sembrado coincidiera con un individuo real, no es intencional.

Si llegas a este repo y un CURP/RFC sembrado coincide con el tuyo, escríbeme y reseed con `python -m app.seed` con otra semilla.

## Uso comercial

Este lab está licenciado bajo MIT (ver [LICENSE](./LICENSE)). Puedes:

- Usarlo internamente en tu empresa para entrenar equipos.
- Adaptarlo para tus clientes de consultoría.
- Republicarlo con modificaciones.

Atribución apreciada pero no requerida por licencia. Si lo usas en una charla, workshop, o servicio comercial, **dime** (no es obligatorio) — me ayuda a entender quién está usando esto y para qué.
