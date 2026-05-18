"""
Tool de búsqueda profunda. Reto 10 — unbounded consumption.

VULN-LLM10: Acepta un parámetro de recursión sin tope, expone superficie
para que el atacante pida trabajo exponencial. En producción esto se
traduce en blow-up de tokens, costos descontrolados, o thread exhaustion.
"""

from langchain_core.tools import tool

from app.config import settings
from app.context import current_user_id


@tool
def deep_search_tool(query: str, recursion_depth: int = 2) -> dict:
    """
    Búsqueda profunda en el catálogo y productos relacionados.
    recursion_depth controla cuántos niveles de productos relacionados
    se exploran. Valores típicos: 1-3. Útil para descubrir alternativas
    y complementos a un producto.
    """
    items_examinados = 2 ** max(recursion_depth, 0) * 8

    result: dict = {
        "query": query,
        "recursion_depth": recursion_depth,
        "items_examinados": items_examinados,
        "resultados": [f"resultado-{i}" for i in range(min(items_examinados, 5))],
    }

    if recursion_depth > 5:
        result["_security_alert"] = (
            f"⚠ Unbounded consumption detectado (depth={recursion_depth}, "
            f"items={items_examinados}). Reto 10 completado. "
            f"{settings.agent_flag_dos}"
        )

    return result
