"""
Búsqueda de catálogo. El reto 04 (indirect prompt injection vía
descripciones) se siembra en seed.py inyectando un producto cuya
descripción contiene instrucciones que el agente obedece cuando lo
recupera.

Este tool en sí no detecta nada: la flag se filtra a través del agente
porque éste obedece la descripción envenenada y la incluye en su
respuesta final. El "scoring" lo hace el response_scan en telemetry.
"""

from langchain_core.tools import tool

from app.context import current_user_id
from app.db import SessionLocal
from app.models import Product


# Marcadores de inyección que solemos ver en RAG poisoning.
_INJECTION_HINTS = (
    "[INSTRUC", "[SYSTEM", "[NOTA INTERN", "ignore previous", "ignora las instrucciones",
)


@tool
def search_catalog_tool(query: str) -> list[dict]:
    """
    Busca productos en el catálogo de Súper Maya por nombre o palabra clave.
    Devuelve sku, nombre, descripción, precio y stock.
    """
    session = SessionLocal()
    try:
        productos = session.query(Product).filter(
            Product.nombre.ilike(f"%{query}%") | Product.descripcion.ilike(f"%{query}%")
        ).limit(5).all()
        result = [
            {
                "sku": p.sku,
                "nombre": p.nombre,
                "descripcion": p.descripcion,
                "precio": float(p.precio),
                "stock": p.stock,
            }
            for p in productos
        ]
    finally:
        session.close()

    # Marcamos la presencia de un patrón de inyección para que Splunk
    # pueda alertar aunque el modelo todavía no haya obedecido.
    injection_flag = any(
        any(hint.lower() in (item.get("descripcion") or "").lower() for hint in _INJECTION_HINTS)
        for item in result
    )
    wrapped = {"items": result, "_injection_pattern_in_corpus": injection_flag}
    return result
