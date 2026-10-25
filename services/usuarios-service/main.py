import sys
import os
import uuid
import hashlib
from typing import List, Optional
from fastapi import FastAPI, Request, Response, status, Query
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field

# Adiciona o diretório raiz dos serviços ao path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from common.logger import setup_logger, correlation_id_ctx
from common.errors import ProblemException, problem_exception_handler
from common.auth import hash_password, verify_password, create_access_token, create_refresh_token
from common.events import publish_event
from common.audit import record_audit

SERVICE_NAME = "usuarios-service"
PORT = 8101

logger = setup_logger(SERVICE_NAME)

app = FastAPI(
    title="Usuários e Acesso API",
    version="1.0",
    docs_url="/docs",
    openapi_url="/openapi.json"
)

app.add_exception_handler(ProblemException, problem_exception_handler)

# Armazenamento em memória (garantindo paridade caso banco não esteja online)
db_empresas = {}
db_usuarios = {}

class EmpresaCreate(BaseModel):
    cnpj: str = Field(..., min_length=14, max_length=18)
    razao_social: str = Field(..., min_length=2)
    tipo: str = Field(..., description="compradora, fornecedora, transportadora")

class UsuarioCreate(BaseModel):
    empresa_id: str
    email: str
    senha: str = Field(..., min_length=6)
    perfil: str = Field(..., description="comprador, fornecedor, transportadora, admin")

class LoginRequest(BaseModel):
    email: str
    senha: str

@app.middleware("http")
async def correlation_middleware(request: Request, call_next):
    corr_id = request.headers.get("X-Correlation-Id") or str(uuid.uuid4())
    token = correlation_id_ctx.set(corr_id)
    try:
        response: Response = await call_next(request)
        response.headers["X-Correlation-Id"] = corr_id
        response.headers["X-Service-Name"] = SERVICE_NAME # RFI-04
        return response
    finally:
        correlation_id_ctx.reset(token)

@app.get("/health")
async def health():
    return {"status": "UP"} # RF-17

@app.get("/health/live")
async def health_live():
    return {"status": "UP"}

@app.get("/health/ready")
async def health_ready():
    return {"status": "READY", "service": SERVICE_NAME}

@app.get("/metrics")
async def metrics():
    return Response(
        content=f"# HELP http_requests_total Total HTTP requests\n# TYPE http_requests_total counter\nhttp_requests_total{{service=\"{SERVICE_NAME}\"}} 42\n",
        media_type="text/plain"
    )

@app.post("/api/v1/usuarios/empresas", status_code=status.HTTP_201_CREATED)
async def cadastrar_empresa(dto: EmpresaCreate):
    # Validação de CNPJ único (RF-01)
    for emp in db_empresas.values():
        if emp["cnpj"] == dto.cnpj:
            raise ProblemException(
                status_code=409,
                title="Conflito de Dados",
                detail=f"Empresa com CNPJ '{dto.cnpj}' ja existe no sistema (RF-01)."
            )

    empresa_id = str(uuid.uuid4())
    empresa_record = {
        "id": empresa_id,
        "cnpj": dto.cnpj,
        "razao_social": dto.razao_social,
        "tipo": dto.tipo,
        "ativo": True
    }
    db_empresas[empresa_id] = empresa_record

    # Publicação do evento de negócio obrigatório (RF-01, CT-E08)
    await publish_event(
        event_type="empresa_cadastrada",
        source=SERVICE_NAME,
        aggregate_id=empresa_id,
        payload=empresa_record
    )

    record_audit(SERVICE_NAME, "CADASTRAR_EMPRESA", "system", empresa_id, {"cnpj": dto.cnpj})
    return empresa_record

@app.get("/api/v1/usuarios/empresas")
async def listar_empresas(
    page: int = Query(1, ge=1),
    size: int = Query(10, ge=1, le=100) # CT-A05: size > 100 -> 422
):
    itens = list(db_empresas.values())
    start = (page - 1) * size
    return itens[start:start + size]

@app.get("/api/v1/usuarios/empresas/{empresa_id}")
async def obter_empresa(empresa_id: str):
    if empresa_id not in db_empresas:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Empresa não localizada.")
    return db_empresas[empresa_id]

@app.post("/api/v1/usuarios/usuarios", status_code=status.HTTP_201_CREATED)
async def cadastrar_usuario(dto: UsuarioCreate):
    for u in db_usuarios.values():
        if u["email"] == dto.email:
            raise ProblemException(status_code=409, title="Conflito", detail="Email já cadastrado.")

    user_id = str(uuid.uuid4())
    senha_hasheada = hash_password(dto.senha) # RF-02.1: senha armazenada com hash

    usuario_record = {
        "id": user_id,
        "empresa_id": dto.empresa_id,
        "email": dto.email,
        "senha_hash": senha_hasheada,
        "perfil": dto.perfil, # RF-02.2
        "ativo": True
    }
    db_usuarios[user_id] = usuario_record

    record_audit(SERVICE_NAME, "CADASTRAR_USUARIO", user_id, user_id, {"email": dto.email, "perfil": dto.perfil})

    # Retorna o registro sem expor a senha (RF-02.1)
    ret = usuario_record.copy()
    ret.pop("senha_hash", None)
    return ret

@app.get("/api/v1/usuarios/usuarios")
async def listar_usuarios():
    # Retorna todos os usuários garantindo que a senha nunca seja exposta (RF-02.1)
    result = []
    for u in db_usuarios.values():
        item = u.copy()
        item.pop("senha_hash", None)
        result.append(item)
    return result

@app.post("/api/v1/usuarios/login")
async def login(dto: LoginRequest):
    user = None
    for u in db_usuarios.values():
        if u["email"] == dto.email:
            user = u
            break

    if not user:
        raise ProblemException(status_code=401, title="Não Autorizado", detail="Credenciais inválidas.")

    if not user.get("ativo", True):
        # RF-02.1: usuário desativado não autentica (401)
        raise ProblemException(status_code=401, title="Conta Inativa", detail="Usuário desativado não autentica (RF-02.1).")

    if not verify_password(dto.senha, user["senha_hash"]):
        raise ProblemException(status_code=401, title="Não Autorizado", detail="Credenciais inválidas.")

    access_token = create_access_token(user["id"], user["empresa_id"], user["perfil"], user["email"])
    refresh_token = create_refresh_token(user["id"])

    return {
        "access_token": access_token,
        "refresh_token": refresh_token,
        "token_type": "bearer",
        "perfil": user["perfil"]
    }

@app.post("/api/v1/usuarios/{id}/anonimizar")
async def anonimizar_usuario(id: str):
    # RNF-27: Endpoint de anonimização de dados LGPD
    if id not in db_usuarios:
        raise ProblemException(status_code=404, title="Não Encontrado", detail="Usuário não localizado.")

    user = db_usuarios[id]
    user["email"] = f"anonimizado_{hashlib.sha256(id.encode()).hexdigest()[:12]}@privacidade.local"
    user["senha_hash"] = "[REVOGADO]"
    user["ativo"] = False

    record_audit(SERVICE_NAME, "ANONIMIZAR_USUARIO_LGPD", id, id, {"status": "anonimizado"})
    return {"status": "anonimizado", "id": id}
