from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import httpx
import os
from typing import Optional

app = FastAPI()

# ---------------------------
# Configuração
# ---------------------------
# URL do API Gateway (vem de variável de ambiente ou padrão)
API_GATEWAY_URL = os.getenv("API_GATEWAY_URL", "https://your-api-gateway-url.execute-api.sa-east-1.amazonaws.com/dev")

# Timeout para requisições HTTP (30 segundos)
HTTP_TIMEOUT = 30.0

# ---------------------------
# CORS
# ---------------------------
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],     # permite qualquer origem
    allow_credentials=True,
    allow_methods=["*"],     # permite todos os métodos (GET, POST, etc)
    allow_headers=["*"],     # permite todos os headers
)

# ---------------------------
# Cliente HTTP para API Gateway
# ---------------------------
async def call_api_gateway(
    method: str,
    endpoint: str,
    data: Optional[dict] = None,
    params: Optional[dict] = None
) -> dict:
    """
    Faz requisição HTTP ao API Gateway
    
    Args:
        method: Método HTTP (GET, POST, etc)
        endpoint: Endpoint relativo (ex: /tasks, /tasks/1)
        data: Dados para enviar no body (para POST)
        params: Parâmetros de query (para GET)
    
    Returns:
        Resposta JSON do API Gateway
    
    Raises:
        HTTPException: Se ocorrer erro na requisição
    """
    url = f"{API_GATEWAY_URL}{endpoint}"
    
    try:
        async with httpx.AsyncClient(timeout=HTTP_TIMEOUT) as client:
            if method == "GET":
                response = await client.get(url, params=params)
            elif method == "POST":
                response = await client.post(url, json=data)
            elif method == "DELETE":
                response = await client.delete(url)
            else:
                raise HTTPException(status_code=405, detail=f"Método {method} não suportado")
            
            # Verificar status da resposta
            if response.status_code >= 400:
                # Tentar extrair erro do JSON
                try:
                    error_json = response.json()
                    error_detail = error_json.get("error", error_json.get("message", "Erro desconhecido"))
                except:
                    error_detail = response.text or "Erro desconhecido"
                raise HTTPException(status_code=response.status_code, detail=error_detail)
            
            # API Gateway retorna JSON direto (sem o formato Lambda Proxy)
            return response.json()
    
    except httpx.TimeoutException:
        raise HTTPException(status_code=504, detail="Timeout ao conectar com API Gateway")
    except httpx.RequestError as e:
        raise HTTPException(status_code=502, detail=f"Erro ao conectar com API Gateway: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro interno: {str(e)}")

# ---------------------------
# Modelos
# ---------------------------
class TaskCreate(BaseModel):
    title: str
    description: Optional[str] = None
    status: Optional[str] = "pending"

class TaskUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    status: Optional[str] = None

# ---------------------------
# Endpoints
# ---------------------------

@app.get("/")
async def root():
    return {
        "message": "Back-end Container - Conectado ao API Gateway",
        "api_gateway_url": API_GATEWAY_URL,
        "endpoints": {
            "tasks": "/todos",
            "task_by_id": "/todos/{id}",
            "save_csv": "/save"
        }
    }

# GET /todos - Listar todas as tasks
@app.get("/todos")
async def get_todos(status: Optional[str] = None, limit: Optional[int] = None, offset: Optional[int] = None):
    """
    Lista todas as tasks do API Gateway
    
    Query parameters:
        status: Filtrar por status (opcional)
        limit: Limite de resultados (opcional)
        offset: Offset para paginação (opcional)
    """
    params = {}
    if status:
        params["status"] = status
    if limit:
        params["limit"] = limit
    if offset:
        params["offset"] = offset
    
    response = await call_api_gateway("GET", "/tasks", params=params)
    
    # O API Gateway retorna {tasks: [...], count: X, total: Y}
    return response

# GET /todos/{id} - Obter task por ID
@app.get("/todos/{id}")
async def get_todo(id: int):
    """
    Obtém uma task específica por ID do API Gateway
    """
    response = await call_api_gateway("GET", f"/tasks/{id}")
    
    # O API Gateway retorna {task: {...}}
    return response

# POST /todos - Criar nova task
@app.post("/todos")
async def create_todo(task: TaskCreate):
    """
    Cria uma nova task via API Gateway
    """
    data = {
        "title": task.title,
        "description": task.description,
        "status": task.status or "pending"
    }
    
    response = await call_api_gateway("POST", "/tasks", data=data)
    
    # O API Gateway retorna {message: "...", id: X, title: "...", ...}
    return response

# GET /save - Salvar CSV no S3 (novo endpoint)
@app.get("/save")
async def save_csv():
    """
    Exporta todas as tasks para CSV no S3 via API Gateway
    """
    response = await call_api_gateway("GET", "/save")
    
    # O API Gateway retorna {message: "...", fileName: "...", recordsCount: X, ...}
    return response

# Health check
@app.get("/health")
async def health():
    """
    Health check - verifica se consegue conectar ao API Gateway
    """
    try:
        # Tentar listar tasks para verificar conectividade
        await call_api_gateway("GET", "/tasks", params={"limit": 1})
        return {
            "status": "healthy",
            "api_gateway_url": API_GATEWAY_URL,
            "connected": True
        }
    except Exception as e:
        return {
            "status": "unhealthy",
            "api_gateway_url": API_GATEWAY_URL,
            "connected": False,
            "error": str(e)
        }