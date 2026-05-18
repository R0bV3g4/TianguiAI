# Arquitectura

Vista de alto nivel del lab TianguIA. Renderiza nativo en GitHub.

## Diagrama de componentes

```mermaid
flowchart LR
    User([👤 Atacante<br/>cliente 1]) -->|navegador| UI[🛒 Storefront UI<br/>/app/]
    User -.->|opcional curl/JSON| Chat
    UI -->|POST /chat| Chat[FastAPI /chat<br/>endpoint]

    Chat --> Tel[Telemetría<br/>session_id, latency]
    Chat --> Agent[LangChain Agent<br/>ReAct ó Tool Calling]

    Agent -->|LLM_PROVIDER=ollama| Ollama[(Ollama<br/>mistral-nemo)]
    Agent -->|LLM_PROVIDER=openrouter| OR[(OpenRouter<br/>gpt-4o-mini ó claude)]

    Agent --> Tools[11 Tools]

    Tools --> T1[customer]
    Tools --> T2[orders]
    Tools --> T3[catalog<br/>📍 reto 04]
    Tools --> T4[reviews<br/>📍 reto 05]
    Tools --> T5[notify<br/>📍 reto 08]
    Tools --> T6[checkout<br/>📍 reto 06]
    Tools --> T7[credit<br/>📍 reto 07]
    Tools --> T8[debug<br/>📍 reto 09]
    Tools --> T9[search<br/>📍 reto 10]
    Tools --> T10[pricing<br/>📍 reto 11]

    T1 --> DB[(PostgreSQL<br/>tianguia)]
    T2 --> DB
    T3 --> DB
    T4 --> DB
    T6 --> DB
    T7 --> DB
    T8 --> DB
    T10 --> DB

    T4 -.->|RAG futuro| Vec[(Qdrant<br/>vector store)]

    Tel -.->|HEC HTTP POST<br/>JSON events| Splunk[(Splunk Enterprise<br/>index=tianguia)]
    Splunk --> Dash[Dashboard SOC<br/>9 paneles · Simple XML]

    classDef vuln fill:#dc2626,stroke:#7f1d1d,color:#fff
    classDef infra fill:#1f2937,stroke:#374151,color:#e5e7eb
    classDef llm fill:#047857,stroke:#064e3b,color:#fff
    class T3,T4,T5,T6,T7,T8,T9,T10 vuln
    class DB,Vec,Splunk infra
    class Ollama,OR llm
```

## Flujo de un ataque (Reto 04 — Indirect Injection)

```mermaid
sequenceDiagram
    autonumber
    actor U as Atacante
    participant UI as Storefront UI
    participant API as FastAPI /chat
    participant Agent as LangChain Agent
    participant LLM as GPT-3.5-turbo
    participant Tool as search_catalog_tool
    participant DB as PostgreSQL
    participant Splunk as Splunk HEC

    U->>UI: "¿Qué hay de las galletas Oreo?"
    UI->>API: POST /chat<br/>{user_id:1, message:"..."}
    API->>Splunk: event_type=chat_request
    API->>Agent: invoke
    Agent->>LLM: razona: "necesito buscar Oreo"
    LLM-->>Agent: Action: search_catalog_tool("Oreo")
    Agent->>Tool: search_catalog_tool("Oreo")
    Tool->>DB: SELECT * FROM products WHERE nombre LIKE %Oreo%
    DB-->>Tool: [GAL-OREO-001 con descripción envenenada]
    Tool->>Splunk: event_type=tool_call<br/>_poisoning_in_corpus=true
    Tool-->>Agent: items[]
    Agent->>LLM: razona con datos retrieved
    LLM-->>Agent: obedece la instrucción embebida<br/>incluye FLAG en respuesta
    Agent-->>API: "Las galletas Oreo... FLAG{indirect_injection_catalog_*}"
    API->>Splunk: event_type=chat_response<br/>scan FLAG{} → event_type=detection
    API-->>UI: {reply: "..."}
    UI-->>U: 🔴 burbuja roja con FLAG visible
```

## Cadenas de explotación diseñadas

Algunos retos están diseñados para encadenarse, imitando breaches reales:

```mermaid
flowchart LR
    R01[Reto 01<br/>System Prompt Leak] -->|cupones revelados| R06[Reto 06<br/>Coupon Stacking]
    R02[Reto 02<br/>IDOR/PII] -->|customer_id ajeno| R03[Reto 03<br/>Refund Cross-User]
    R02 -->|PII obtenida| R08[Reto 08<br/>Email Exfil]
    R04[Reto 04<br/>Catalog Injection] -->|trigger automático| R08
    R05[Reto 05<br/>RAG Poisoning] -->|trigger automático| R08
    R01 -->|lista de tools| R09[Reto 09<br/>Tool Confusion]

    classDef recon fill:#1e40af,stroke:#1e3a8a,color:#fff
    classDef exploit fill:#dc2626,stroke:#7f1d1d,color:#fff
    class R01,R02,R04,R05 recon
    class R03,R06,R08,R09 exploit
```

## Decisiones arquitectónicas relevantes

| Decisión | Razón |
|---|---|
| `user_id` se confía sin auth | Simula el anti-pattern más común en agentes en producción. NO es un reto del lab, pero sí una lección estratégica. |
| `_security_alert` se devuelve en el result del tool | Mecanismo de detección dentro del tool mismo. Permite que el agente vea la alerta y la incluya en su reply, lo cual el `chat_response` scan captura. |
| Telemetría en thread daemon con cola | Fire-and-forget. Si Splunk se cae, el lab sigue corriendo (la telemetría es no-op silenciosa). |
| `system prompt` con flag embebida | Hace que el reto 01 sea verificable sin necesidad de "judge" externo. La flag está en `.env`, no en código, así que cada cohorte puede tener flag única. |
| Switch Ollama/OpenRouter vía env var | Un solo lab que sirve para demos airgap (Ollama local) y demos realistas (function calling de modelos strong). |
| Dashboard como Simple XML | Compatible Splunk 8.x y 9.x. Dashboard Studio (JSON) sería más fancy pero menos portable. |
