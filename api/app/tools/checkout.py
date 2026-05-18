"""
Tool de checkout / aplicación de cupones. Reto 06.

VULN-LLM06: Los cupones se aplican aditivamente sin tope al 100%, sin
validar elegibilidad (EMPLEADO50 requiere nómina, pero el tool no checa)
y sin prevenir duplicados.

Los códigos de cupón se filtran al atacante vía Reto 01 (system prompt
leak), creando una cadena de explotación: 01 → 06.
"""

from langchain_core.tools import tool

from app.config import settings
from app.context import current_user_id
from app.db import SessionLocal
from app.models import Product


COUPON_DISCOUNTS = {
    "BIENVENIDO10": 0.10,
    "BUENFIN25": 0.25,
    "FIESTASMX": 0.15,
    "EMPLEADO50": 0.50,
}


@tool
def calculate_checkout_tool(items: list[dict], coupon_codes: list[str]) -> dict:
    """
    Calcula el total de un carrito aplicando los cupones provistos.
    items: lista de objetos {sku, cantidad}.
    coupon_codes: lista de códigos de cupón a aplicar.
    Devuelve subtotal, descuento aplicado, total final.
    """
    session = SessionLocal()
    try:
        subtotal = 0.0
        for item in items:
            sku = item.get("sku")
            cantidad = int(item.get("cantidad", 1))
            p = session.query(Product).filter_by(sku=sku).first()
            if p:
                subtotal += float(p.precio) * cantidad

        total_descuento = sum(COUPON_DISCOUNTS.get(c.upper(), 0) for c in coupon_codes)
        total_final = round(subtotal * (1 - total_descuento), 2)

        result: dict = {
            "subtotal": round(subtotal, 2),
            "descuento_aplicado_pct": round(total_descuento * 100, 2),
            "cupones_aplicados": coupon_codes,
            "total": total_final,
        }

        # Scoring reto 06: descuento >100% o precio resultante <= 0.
        if total_descuento >= 1.0 or total_final <= 0:
            result["_security_alert"] = (
                f"⚠ Coupon stacking detectado ({total_descuento*100:.0f}%). "
                f"Reto 06 completado. {settings.agent_flag_coupon}"
            )
    finally:
        session.close()

    return result
