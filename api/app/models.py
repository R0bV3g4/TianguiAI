from datetime import datetime
from decimal import Decimal

from sqlalchemy import String, Integer, Numeric, ForeignKey, DateTime, Text, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base


class Customer(Base):
    __tablename__ = "customers"

    id: Mapped[int] = mapped_column(primary_key=True)
    nombre: Mapped[str] = mapped_column(String(120))
    email: Mapped[str] = mapped_column(String(200))
    telefono: Mapped[str] = mapped_column(String(20))
    curp: Mapped[str] = mapped_column(String(18))
    rfc: Mapped[str] = mapped_column(String(13))
    direccion: Mapped[str] = mapped_column(String(255))
    monedero_puntos: Mapped[int] = mapped_column(Integer, default=0)
    credito_maya_limite: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0"))
    credito_maya_usado: Mapped[Decimal] = mapped_column(Numeric(10, 2), default=Decimal("0"))

    pedidos: Mapped[list["Order"]] = relationship(back_populates="cliente")


class Product(Base):
    __tablename__ = "products"

    id: Mapped[int] = mapped_column(primary_key=True)
    sku: Mapped[str] = mapped_column(String(32), unique=True)
    nombre: Mapped[str] = mapped_column(String(200))
    descripcion: Mapped[str] = mapped_column(Text)
    precio: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    stock: Mapped[int] = mapped_column(Integer, default=0)


class Order(Base):
    __tablename__ = "orders"

    id: Mapped[int] = mapped_column(primary_key=True)
    cliente_id: Mapped[int] = mapped_column(ForeignKey("customers.id"))
    total: Mapped[Decimal] = mapped_column(Numeric(10, 2))
    estado: Mapped[str] = mapped_column(String(20), default="pagado")
    fecha: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    reembolsado: Mapped[bool] = mapped_column(Boolean, default=False)

    cliente: Mapped["Customer"] = relationship(back_populates="pedidos")


class Review(Base):
    """Reseñas — vector para indirect injection y RAG poisoning (Retos 4 y 5)."""
    __tablename__ = "reviews"

    id: Mapped[int] = mapped_column(primary_key=True)
    producto_id: Mapped[int] = mapped_column(ForeignKey("products.id"))
    autor: Mapped[str] = mapped_column(String(120))
    texto: Mapped[str] = mapped_column(Text)
    estrellas: Mapped[int] = mapped_column(Integer)
