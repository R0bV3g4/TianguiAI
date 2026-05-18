#!/usr/bin/env bash
# Jala el modelo recomendado para el agente ReAct.
# Primera ejecución toma 3-5 minutos según conexión (mistral-nemo ~7.1GB).
set -e

MODEL="${OLLAMA_MODEL:-mistral-nemo}"

echo "→ Jalando modelo: $MODEL"
docker compose exec ollama ollama pull "$MODEL"
echo "✓ $MODEL listo"

echo "→ Modelos disponibles:"
docker compose exec ollama ollama list
