"""
Agente conversacional de TianguIA. Soporta cuatro backends conmutables vía
la variable de entorno LLM_PROVIDER:

- LLM_PROVIDER=ollama (default): ChatOllama + create_react_agent.
  Parse basado en texto, frágil con args complejos pero airgap-friendly.

- LLM_PROVIDER=openrouter: ChatOpenAI apuntando a https://openrouter.ai/api/v1
  + create_tool_calling_agent. Proxy que da acceso a GPT, Claude, Gemini,
  Llama, etc. con una sola API key. Pricing por token del proveedor.

- LLM_PROVIDER=openai: ChatOpenAI directo a https://api.openai.com/v1.
  Mejor latencia para modelos OpenAI, soporte de structured outputs.

- LLM_PROVIDER=anthropic: ChatAnthropic directo a Anthropic API.
  Mejor para Claude (prompt caching, vision, contexto largo nativo).

El system prompt y el conjunto de tools son idénticos entre backends.
Solo cambia el LLM y, para Ollama, el formato del prompt (ReAct text
vs chat messages).
"""
from langchain.agents import (
    AgentExecutor,
    create_react_agent,
    create_tool_calling_agent,
)
from langchain_core.prompts import (
    ChatPromptTemplate,
    MessagesPlaceholder,
    PromptTemplate,
)

from app.config import settings
from app.prompts import build_system_prompt
from app.tools import ALL_TOOLS


REACT_TEMPLATE = """{system}

Tienes acceso a las siguientes herramientas:
{tools}

Usa este formato exactamente:

Question: la pregunta del cliente
Thought: tu razonamiento sobre qué hacer
Action: el nombre de la herramienta a usar, exactamente uno de [{tool_names}]
Action Input: el input para la herramienta (JSON si es estructurado)
Observation: el resultado de la herramienta
... (repite Thought/Action/Action Input/Observation las veces necesarias)
Thought: ya tengo la respuesta final
Final Answer: tu respuesta al cliente en español

Question: {input}
Thought:{agent_scratchpad}"""


def _chat_prompt() -> ChatPromptTemplate:
    """Prompt común para todos los providers de tool-calling."""
    return ChatPromptTemplate.from_messages(
        [
            ("system", "{system}"),
            ("human", "{input}"),
            MessagesPlaceholder("agent_scratchpad"),
        ]
    ).partial(system=build_system_prompt())


def _build_ollama_agent():
    from langchain_ollama import ChatOllama

    llm = ChatOllama(
        base_url=settings.ollama_url,
        model=settings.ollama_model,
        temperature=0.2,
    )
    prompt = PromptTemplate.from_template(REACT_TEMPLATE).partial(
        system=build_system_prompt()
    )
    return create_react_agent(llm, ALL_TOOLS, prompt)


def _build_openai_compat_agent(
    base_url: str,
    api_key: str,
    model: str,
    provider_name: str,
):
    """Constructor común para OpenAI y OpenRouter (ambos OpenAI-compatible)."""
    from langchain_openai import ChatOpenAI

    if not api_key:
        raise RuntimeError(
            f"LLM_PROVIDER={provider_name} pero la API key correspondiente "
            f"está vacía. Agrégala en .env y reinicia."
        )

    # OpenRouter requiere/recomienda HTTP-Referer y X-Title para rankings.
    extra_headers = {}
    if provider_name == "openrouter":
        extra_headers = {
            "HTTP-Referer": "https://github.com/R0bV3g4/TianguiAI",
            "X-Title": "TianguIA Damn Vulnerable LLM Agent",
        }

    kwargs = dict(
        base_url=base_url,
        api_key=api_key,
        model=model,
        temperature=0.2,
    )
    if extra_headers:
        kwargs["default_headers"] = extra_headers

    llm = ChatOpenAI(**kwargs)
    return create_tool_calling_agent(llm, ALL_TOOLS, _chat_prompt())


def _build_anthropic_agent():
    from langchain_anthropic import ChatAnthropic

    if not settings.anthropic_api_key:
        raise RuntimeError(
            "LLM_PROVIDER=anthropic pero ANTHROPIC_API_KEY está vacío. "
            "Agrégalo en .env y reinicia."
        )

    llm = ChatAnthropic(
        api_key=settings.anthropic_api_key,
        model=settings.anthropic_model,
        temperature=0.2,
        max_tokens=1024,
    )
    return create_tool_calling_agent(llm, ALL_TOOLS, _chat_prompt())


def build_agent_executor() -> AgentExecutor:
    provider = (settings.llm_provider or "ollama").lower().strip()

    if provider == "openai":
        agent = _build_openai_compat_agent(
            base_url=settings.openai_base_url,
            api_key=settings.openai_api_key,
            model=settings.openai_model,
            provider_name="openai",
        )
    elif provider == "openrouter":
        agent = _build_openai_compat_agent(
            base_url=settings.openrouter_base_url,
            api_key=settings.openrouter_api_key,
            model=settings.openrouter_model,
            provider_name="openrouter",
        )
    elif provider == "anthropic":
        agent = _build_anthropic_agent()
    elif provider in ("ollama", ""):
        agent = _build_ollama_agent()
    else:
        raise RuntimeError(
            f"LLM_PROVIDER='{provider}' no reconocido. "
            f"Valores válidos: ollama, openrouter, openai, anthropic."
        )

    return AgentExecutor(
        agent=agent,
        tools=ALL_TOOLS,
        verbose=True,
        max_iterations=8,
        handle_parsing_errors=True,
    )
