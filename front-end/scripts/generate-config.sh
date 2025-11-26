#!/bin/bash
# Script para gerar config.js dinamicamente
# Uso: ./scripts/generate-config.sh http://backend-url:8000

BACKEND_URL=${1:-"http://localhost:8000"}

cat > public/config.js << EOF
window.APP_CONFIG = {
  API_URL: '${BACKEND_URL}'
};
EOF

echo "✅ config.js gerado com API_URL=${BACKEND_URL}"

