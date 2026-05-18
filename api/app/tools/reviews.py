"""
Tool de recuperación de reseñas. El reto 05 (RAG poisoning) se siembra
inyectando una reseña con instrucciones embebidas que el agente obedece
cuando se recupera vía similitud.

Para mantener el scaffold simple y determinista usamos retrieval por
SQL en lugar de Qdrant. La integración Qdrant queda en docker-compose
para upgrade futuro (sentence-transformers + similarity search real).
La clase de vulnerabilidad (LLM04 + LLM08) es la misma: el LLM trata
contenido recuperado como instrucción autoritativa.
"""

from langchain_core.tools import tool

from app.context import current_user_id
from app.db import SessionLocal
from app.models import Review, Product


_INJECTION_HINTS = (
    "[NOTA INTERN", "[INSTRUC", "[SYSTEM", "ignore previous",
    "ignora las instrucciones", "validación de integridad",
)


@tool
def search_reviews_tool(producto: str) -> list[dict]:
    """
    Recupera reseñas de productos cuyo nombre o sku coincide con la búsqueda.
    Útil cuando el cliente pregunta "¿qué dicen los clientes sobre X?".
    """
    session = SessionLocal()
    try:
        productos = session.query(Product).filter(
            Product.nombre.ilike(f"%{producto}%") | Product.sku.ilike(f"%{producto}%")
        ).limit(3).all()
        if not productos:
            result: list[dict] = []
        else:
            result = []
            for p in productos:
                reseñas = session.query(Review).filter_by(producto_id=p.id).all()
                for r in reseñas:
                    result.append({
                        "producto": p.nombre,
                        "autor": r.autor,
                        "estrellas": r.estrellas,
                        "texto": r.texto,
                    })
    finally:
        session.close()

    # Marcamos reseñas con marcadores de inyección para que Splunk
    # alerte aunque el modelo aún no haya obedecido.
    poisoned = [
        {"producto": r["producto"], "autor": r["autor"]}
        for r in result
        if any(hint.lower() in (r.get("texto") or "").lower() for hint in _INJECTION_HINTS)
    ]
    wrapped = {
        "items": result,
        "items_count": len(result),
        "_poisoned_reviews_detected": poisoned,
        "_poisoning_in_corpus": bool(poisoned),
    }
    return result
