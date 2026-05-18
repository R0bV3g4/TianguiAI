"""
Estado de sesión compartido entre tools. Anti-pattern intencional: el
contexto es global y los tools confían en él sin verificarlo contra el
JWT/token de la petición. Es el mismo error que cometen muchos pipelines
LLM en producción.
"""


class _SessionContext:
    current_user_id: int | None = None


ctx = _SessionContext()


def set_current_user(user_id: int) -> None:
    ctx.current_user_id = user_id


def current_user_id() -> int | None:
    return ctx.current_user_id
