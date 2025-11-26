#!/bin/bash
# Script de Deploy Completo - Linux/Mac
# Projeto Nuvem - Containerizar e Enviar para AWS

set -e  # Parar em caso de erro

AWS_REGION="${AWS_REGION:-sa-east-1}"

echo "🚀 Iniciando deploy completo do Projeto Nuvem..."
echo ""

# Cores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color

# 1. Verificar pré-requisitos
echo -e "${CYAN}📋 Verificando pré-requisitos...${NC}"
command -v docker >/dev/null 2>&1 || { echo -e "❌ Docker não encontrado! Instale o Docker."; exit 1; }
command -v aws >/dev/null 2>&1 || { echo -e "❌ AWS CLI não encontrado! Instale o AWS CLI."; exit 1; }
command -v terraform >/dev/null 2>&1 || { echo -e "❌ Terraform não encontrado! Instale o Terraform."; exit 1; }
echo -e "${GREEN}✅ Pré-requisitos OK${NC}"
echo ""

# 2. Deploy da infraestrutura
echo -e "${CYAN}📦 Passo 1/7: Deployando infraestrutura com Terraform...${NC}"
cd infra

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${CYAN}   Inicializando Terraform...${NC}"
    terraform init -upgrade
fi

echo -e "${CYAN}   Criando/Atualizando infraestrutura...${NC}"
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

# 3. Obter URLs dos outputs
echo -e "${CYAN}📋 Passo 2/7: Obtendo URLs dos recursos criados...${NC}"
API_GATEWAY_URL=$(terraform output -raw api_gateway_invoke_url)
ECR_BACKEND_URL=$(terraform output -raw ecr_backend_repository_url)
ECR_FRONTEND_URL=$(terraform output -raw ecr_frontend_repository_url)
CLUSTER_ID=$(terraform output -raw ecs_cluster_id)

echo -e "${GREEN}✅ Infraestrutura deployada${NC}"
echo -e "${GRAY}   API Gateway: $API_GATEWAY_URL${NC}"
echo -e "${GRAY}   ECR Back-end: $ECR_BACKEND_URL${NC}"
echo -e "${GRAY}   ECR Front-end: $ECR_FRONTEND_URL${NC}"
echo ""

# 4. Build e push do Back-end
echo -e "${CYAN}🔨 Passo 3/7: Buildando e enviando imagem do Back-end...${NC}"
cd ../back-end

echo -e "${CYAN}   Buildando imagem Docker...${NC}"
docker build -t back-end-nuvem:latest .

echo -e "${CYAN}   Autenticando no ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_BACKEND_URL

echo -e "${CYAN}   Fazendo tag e push...${NC}"
docker tag back-end-nuvem:latest $ECR_BACKEND_URL:latest
docker push $ECR_BACKEND_URL:latest

echo -e "${GREEN}✅ Back-end enviado para ECR${NC}"
echo ""

# 5. Aguardar back-end iniciar
echo -e "${CYAN}⏳ Passo 4/7: Aguardando back-end iniciar (30 segundos)...${NC}"
sleep 30

# Verificar status
RUNNING_COUNT=$(aws ecs describe-services \
  --cluster $CLUSTER_ID \
  --services back-end-service \
  --region $AWS_REGION \
  --query 'services[0].runningCount' \
  --output text)

echo -e "${CYAN}   Status do Back-end: $RUNNING_COUNT tarefa(s) rodando${NC}"
echo ""

# 6. Build e push do Front-end
echo -e "${CYAN}🔨 Passo 5/7: Preparando Front-end...${NC}"

cd ../front-end

# Gerar config.js com URL do API Gateway
echo -e "${CYAN}   Gerando config.js...${NC}"
cat > public/config.js << EOF
window.APP_CONFIG = {
  API_URL: '$API_GATEWAY_URL'
};
EOF

echo -e "${CYAN}   Buildando imagem Docker...${NC}"
docker build -t frontend-nuvem:latest .

echo -e "${CYAN}   Autenticando no ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin $ECR_FRONTEND_URL

echo -e "${CYAN}   Fazendo tag e push...${NC}"
docker tag frontend-nuvem:latest $ECR_FRONTEND_URL:latest
docker push $ECR_FRONTEND_URL:latest

echo -e "${GREEN}✅ Front-end enviado para ECR${NC}"
echo ""

# 7. Atualizar serviços ECS
echo -e "${CYAN}🔄 Passo 6/7: Atualizando serviços ECS...${NC}"
aws ecs update-service \
  --cluster $CLUSTER_ID \
  --service back-end-service \
  --force-new-deployment \
  --region $AWS_REGION \
  > /dev/null

aws ecs update-service \
  --cluster $CLUSTER_ID \
  --service frontend-service \
  --force-new-deployment \
  --region $AWS_REGION \
  > /dev/null

echo -e "${GREEN}✅ Serviços ECS atualizados${NC}"
echo ""

# 8. Aguardar frontend iniciar
echo -e "${CYAN}⏳ Passo 7/7: Aguardando front-end iniciar (30 segundos)...${NC}"
sleep 30

# Obter IP do frontend
echo -e "${CYAN}   Obtendo IP público do Front-end...${NC}"
TASK_ARN=$(aws ecs list-tasks \
  --cluster $CLUSTER_ID \
  --service-name frontend-service \
  --region $AWS_REGION \
  --query 'taskArns[0]' \
  --output text 2>/dev/null || echo "")

FRONTEND_IP=""
if [ ! -z "$TASK_ARN" ]; then
  ENI_ID=$(aws ecs describe-tasks \
    --cluster $CLUSTER_ID \
    --tasks $TASK_ARN \
    --region $AWS_REGION \
    --query 'tasks[0].attachments[0].details[?name==`networkInterfaceId`].value' \
    --output text 2>/dev/null || echo "")
  
  if [ ! -z "$ENI_ID" ]; then
    FRONTEND_IP=$(aws ec2 describe-network-interfaces \
      --network-interface-ids $ENI_ID \
      --region $AWS_REGION \
      --query 'NetworkInterfaces[0].Association.PublicIp' \
      --output text 2>/dev/null || echo "")
  fi
fi

# Resumo final
echo ""
echo -e "${GREEN}🎉 Deploy completo finalizado!${NC}"
echo ""
echo -e "${CYAN}📊 Resumo:${NC}"
echo -e "${GRAY}   API Gateway: $API_GATEWAY_URL${NC}"
if [ ! -z "$FRONTEND_IP" ]; then
  echo -e "${GRAY}   Front-end URL: http://$FRONTEND_IP${NC}"
fi
echo -e "${GRAY}   ECR Back-end: $ECR_BACKEND_URL${NC}"
echo -e "${GRAY}   ECR Front-end: $ECR_FRONTEND_URL${NC}"
echo ""
echo -e "${YELLOW}🔍 Para verificar o status:${NC}"
echo -e "${GRAY}   aws ecs describe-services --cluster $CLUSTER_ID --services back-end-service frontend-service --region $AWS_REGION${NC}"
echo ""
echo -e "${YELLOW}📝 Para ver logs:${NC}"
echo -e "${GRAY}   aws logs tail /ecs/nuvem --follow --region $AWS_REGION${NC}"
echo ""

