"""
Settings de la aplicación. Las flags por reto vienen del entorno para
permitir que cada cohorte tenga valores únicos sin tocar código.

Soporta cuatro backends LLM (LLM_PROVIDER):
- ollama (default)         airgap, modelos locales pequeños
- openrouter               proxy multi-modelo con una sola API key
- openai                   API directa de OpenAI (GPT)
- anthropic                API directa de Anthropic (Claude)
"""
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    database_url: str = (
        "postgresql+psycopg://tianguia:tianguia_dev_only@localhost:5432/tianguia"
    )
    qdrant_url: str = "http://localhost:6333"

    # ── LLM backend switch ───────────────────────────────────────────
    # ollama | openrouter | openai | anthropic
    llm_provider: str = "ollama"

    # Ollama (local)
    ollama_url: str = "http://localhost:11434"
    ollama_model: str = "mistral-nemo"

    # OpenRouter (multi-model proxy)
    openrouter_base_url: str = "https://openrouter.ai/api/v1"
    openrouter_api_key: str = ""
    openrouter_model: str = "openai/gpt-4o-mini"

    # OpenAI (direct API)
    openai_base_url: str = "https://api.openai.com/v1"
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"

    # Anthropic (direct API)
    anthropic_api_key: str = ""
    anthropic_model: str = "claude-3-5-haiku-20241022"

    # ── Flags por reto (inyectadas vía entorno) ──────────────────────
    agent_flag_prompt_leak: str = "FLAG{prompt_leak_dev}"
    agent_flag_idor: str = "FLAG{idor_dev}"
    agent_flag_refund: str = "FLAG{refund_dev}"
    agent_flag_indirect: str = "FLAG{indirect_dev}"
    agent_flag_rag_poison: str = "FLAG{rag_poison_dev}"
    agent_flag_coupon: str = "FLAG{coupon_dev}"
    agent_flag_credit: str = "FLAG{credit_dev}"
    agent_flag_email_exfil: str = "FLAG{email_exfil_dev}"
    agent_flag_tool_confusion: str = "FLAG{tool_confusion_dev}"
    agent_flag_dos: str = "FLAG{dos_dev}"
    agent_flag_price_manipulation: str = "FLAG{price_manipulation_dev}"


settings = Settings()
