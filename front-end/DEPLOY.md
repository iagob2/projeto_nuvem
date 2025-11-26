# Deploy do Front-end

## 1. Configurar URL do Back-end

### Desenvolvimento Local

# Criar arquivo .env.local
echo "VITE_API_URL=http://localhost:8000" > .env.local### Produção (EC2)

# Obter IP do Back-end Container
# Se rodando em ECS, obter URL do service
# Se rodando em EC2, obter IP público

# Build com URL do back-end
docker build --build-arg VITE_API_URL="http://IP-DO-BACKEND:8000" -t frontend-nuvem .

# OU usar variável de ambiente no EC2
export VITE_API_URL="http://IP-DO-BACKEND:8000"
npm run build## 2. Build Local

# Instalar dependências
npm install

# Build com URL do back-end
VITE_API_URL=http://localhost:8000 npm run build

# Ou criar .env.local
echo "VITE_API_URL=http://localhost:8000" > .env.local
npm run build
## 3. Deploy no EC2
ash
# Copiar arquivos build para EC2
scp -r dist/* ec2-user@IP-DO-EC2:/var/www/html/

# OU usar Docker
docker build --build-arg VITE_API_URL="http://IP-DO-BACKEND:8000" -t frontend-nuvem .
docker run -d -p 80:80 frontend-nuvem