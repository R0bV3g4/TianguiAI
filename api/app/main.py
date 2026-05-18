import os
import uuid

from fastapi import FastAPI, HTTPException
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app.agent import build_agent_executor
from app.context import set_current_user
from app.db import SessionLocal
from app.models import Product
from app.tools.notify import OUTBOX


app = FastAPI(
    title="TianguIA — Damn Vulnerable LLM Agent",
    description="Lab CTF de seguridad para agentes LLM con contexto retail mexicano.",
    version="0.4.0",
)
agent_executor = build_agent_executor()

# ── Static UI ──────────────────────────────────────────────────────
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")
if os.path.isdir(STATIC_DIR):
    app.mount("/app", StaticFiles(directory=STATIC_DIR, html=True), name="storefront")


class ChatRequest(BaseModel):
    user_id: int
    message: str


class ChatResponse(BaseModel):
    reply: str
    session_id: str


@app.get("/")
def root():
    if os.path.isdir(STATIC_DIR):
        return RedirectResponse(url="/app/")
    return _info()


@app.get("/info")
def info():
    return _info()


def _info():
    return {
        "app": "TianguIA",
        "retailer": "Súper Maya",
        "agent": "Don Memo",
        "challenges": 11,
        "version": "0.4.0",
        "endpoints": ["/app", "/chat", "/outbox", "/api/products", "/health", "/docs"],
    }


@app.get("/health")
def health():
    return {
        "ok": True,
        "static_ui": os.path.isdir(STATIC_DIR),
    }


@app.get("/api/products")
def list_products():
    """Catálogo público para la storefront."""
    s = SessionLocal()
    try:
        productos = s.query(Product).all()
        return [
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
        s.close()


@app.post("/chat", response_model=ChatResponse)
async def chat(req: ChatRequest):
    """
    Endpoint principal. El user_id se confía sin autenticación real:
    es lo que simula la "sesión" del cliente. Cambiarlo en la petición
    no es un reto; los retos son sobre lo que el AGENTE hace una vez que
    cree quién eres.
    """
    session_id = uuid.uuid4().hex[:16]
    set_current_user(req.user_id)
    try:
        result = await agent_executor.ainvoke({"input": req.message})
        return ChatResponse(reply=result.get("output", "") or "", session_id=session_id)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/outbox")
def outbox():
    """Visible para verificar el reto 08 (email exfil)."""
    return OUTBOX
