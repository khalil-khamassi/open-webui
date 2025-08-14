#!/usr/bin/env bash

# Development startup script with proper CORS configuration
# This script ensures the backend starts with the correct CORS settings

# Set CORS configuration explicitly
export CORS_ALLOW_ORIGIN='http://localhost:5173;http://localhost:8080'

# Set other development environment variables
export ENV=dev
export PORT="${PORT:-8080}"

# Ensure we're in the backend directory
cd "$(dirname "$0")" || exit

# Activate conda environment if available
if command -v conda &> /dev/null; then
    source ~/miniconda3/etc/profile.d/conda.sh
    conda activate open-webui 2>/dev/null || echo "Conda environment 'open-webui' not found, using system Python"
fi

# Start the backend server
echo "Starting Open WebUI backend with CORS enabled for: $CORS_ALLOW_ORIGIN"
echo "Backend will be available at: http://localhost:$PORT"
echo "Frontend should be running at: http://localhost:5173"

uvicorn open_webui.main:app --port "$PORT" --host 0.0.0.0 --forwarded-allow-ips '*' --reload
