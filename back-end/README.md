# Back-end Container - Projeto Nuvem

## 📋 Descrição

Back-end Container desenvolvido em FastAPI que funciona como intermediário entre o frontend e o API Gateway da AWS. 

**Arquitetura:**
```
Frontend → Back-end Container (FastAPI) → API Gateway → Lambdas → RDS MySQL / S3
```

## 🔌 Endpoints do Back-end

| Método | Endpoint | Descrição | Chama API Gateway |
|--------|----------|-----------|-------------------|
| `GET` | `/` | Informações da API | - |
| `GET` | `/health` | Health check | `GET /tasks` (limit=1) |
| `GET` | `/todos` | Listar tasks | `GET /tasks` |
| `GET` | `/todos/{id}` | Obter task por ID | `GET /tasks/{id}` |
| `POST` | `/todos` | Criar task | `POST /tasks` |
| `GET` | `/save` | Exportar CSV para S3 | `GET /save` |

## 🚀 Como Executar

### 1. Configurar URL do API Gateway

**Opção A: Usando arquivo `variaveis.end`**
```env
API_GATEWAY_URL=https://seu-api-gateway.execute-api.sa-east-1.amazonaws.com/dev
```

**Opção B: Variável de ambiente**
```bash
export API_GATEWAY_URL="https://seu-api-gateway.execute-api.sa-east-1.amazonaws.com/dev"
```

**Obter URL do API Gateway:**
```bash
cd projeto_nuvem/infra
terraform output api_gateway_url
```

### 2. Instalar Dependências

```bash
pip install -r requirements.txt
```

### 3. Executar Localmente

```bash
uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

O back-end estará disponível em: `http://localhost:8000`

### 4. Executar com Docker

```bash
# Build da imagem
docker build -t backend-container .

# Executar container
docker run -p 8000:8000 -e API_GATEWAY_URL="https://seu-api-gateway.execute-api.sa-east-1.amazonaws.com/dev" backend-container
```

### 5. Executar com Docker Compose

```bash
# Editar variaveis.end com a URL do API Gateway
echo "API_GATEWAY_URL=https://seu-api-gateway.execute-api.sa-east-1.amazonaws.com/dev" > variaveis.end

# Executar
docker-compose up --build
```

## 📡 Mapeamento de Endpoints

### Back-end → API Gateway → Lambda

| Back-end | API Gateway | Lambda | Banco |
|----------|-------------|--------|-------|
| `GET /todos` | `GET /tasks` | `ListarTasks` | MySQL (SELECT *) |
| `GET /todos/{id}` | `GET /tasks/{id}` | `ObterTaskPorId` | MySQL (SELECT WHERE id) |
| `POST /todos` | `POST /tasks` | `CriarTask` | MySQL (INSERT) |
| `GET /save` | `GET /save` | `SalvarCSV` | MySQL (SELECT *) + S3 (putObject) |

## 🔍 Exemplos de Uso

### Listar Tasks
```bash
curl http://localhost:8000/todos
```

### Listar Tasks com Filtro
```bash
curl "http://localhost:8000/todos?status=pending&limit=10"
```

### Obter Task por ID
```bash
curl http://localhost:8000/todos/1
```

### Criar Task
```bash
curl -X POST http://localhost:8000/todos \
  -H "Content-Type: application/json" \
  -d '{"title": "Nova Task", "description": "Descrição", "status": "pending"}'
```

### Exportar CSV para S3
```bash
curl http://localhost:8000/save
```

### Health Check
```bash
curl http://localhost:8000/health
```

## ⚙️ Variáveis de Ambiente

| Variável | Descrição | Obrigatória | Padrão |
|----------|-----------|-------------|--------|
| `API_GATEWAY_URL` | URL base do API Gateway | Sim | - |

## 🗄️ Banco de Dados

- **Tipo:** MySQL (RDS)
- **Acesso:** Via Lambdas através do Secrets Manager
- **Tabela:** `tasks`
- **Estrutura:**
  - `id` (INT, AUTO_INCREMENT)
  - `title` (VARCHAR(255))
  - `description` (TEXT)
  - `status` (VARCHAR(50))
  - `created_at` (TIMESTAMP)
  - `updated_at` (TIMESTAMP)

## 📦 Armazenamento

- **S3 Bucket:** Armazena arquivos CSV exportados
- **Path no S3:** `data/tasks_YYYY-MM-DD_timestamp.csv`

## 🐛 Troubleshooting

### Erro: "Erro ao conectar com API Gateway"
- Verifique se a URL do API Gateway está correta
- Verifique se o API Gateway está implantado
- Verifique se há conectividade de rede

### Erro: "Timeout ao conectar com API Gateway"
- Aumente o timeout no código (HTTP_TIMEOUT)
- Verifique a latência da rede

### Erro: "Campo title é obrigatório"
- Verifique se está enviando o campo `title` no body da requisição

## 📝 Notas Importantes

1. **O back-end NÃO conecta diretamente ao banco de dados**
   - Todas as operações passam pelo API Gateway
   - As Lambdas são responsáveis pela conexão com MySQL

2. **O S3 é usado apenas para armazenar CSVs**
   - Não é DynamoDB
   - A Lambda `SalvarCSV` faz o SELECT no MySQL e salva CSV no S3

3. **4 Lambdas configuradas:**
   - `CriarTask`: INSERT no MySQL
   - `ListarTasks`: SELECT * no MySQL
   - `ObterTaskPorId`: SELECT WHERE id no MySQL
   - `SalvarCSV`: SELECT * no MySQL + putObject no S3

