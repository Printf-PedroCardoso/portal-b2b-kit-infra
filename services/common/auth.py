import os
import time
import hashlib
from typing import Optional, List
from fastapi import Request, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from .errors import ProblemException

JWT_SECRET_KEY = os.getenv("JWT_SECRET_KEY", "chave-secreta-poc-portal-b2b-super-segura-2026")
JWT_ALGORITHM = os.getenv("JWT_ALGORITHM", "HS256")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "15")) # RNF-17: 15 min
REFRESH_TOKEN_EXPIRE_HOURS = int(os.getenv("REFRESH_TOKEN_EXPIRE_HOURS", "8"))   # RNF-17: 8 h

security_bearer = HTTPBearer(auto_error=False)

def hash_password(password: str) -> str:
    """
    Gera hash seguro com salt SHA-256 para senhas de usuários (RF-02.1).
    """
    salt = "portal_b2b_salt_secure"
    return hashlib.sha256(f"{salt}{password}".encode("utf-8")).hexdigest()

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return hash_password(plain_password) == hashed_password

def create_access_token(user_id: str, empresa_id: str, perfil: str, email: str) -> str:
    now = int(time.time())
    payload = {
        "sub": user_id,
        "empresaId": empresa_id,
        "perfil": perfil,
        "email": email,
        "iat": now,
        "exp": now + (ACCESS_TOKEN_EXPIRE_MINUTES * 60),
        "type": "access"
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def create_refresh_token(user_id: str) -> str:
    now = int(time.time())
    payload = {
        "sub": user_id,
        "iat": now,
        "exp": now + (REFRESH_TOKEN_EXPIRE_HOURS * 3600),
        "type": "refresh"
    }
    return jwt.encode(payload, JWT_SECRET_KEY, algorithm=JWT_ALGORITHM)

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, JWT_SECRET_KEY, algorithms=[JWT_ALGORITHM])
    except jwt.ExpiredSignatureError:
        raise ProblemException(
            status_code=401,
            title="Token Expirado",
            detail="O token JWT fornecido está expirado (RNF-17)."
        )
    except jwt.InvalidTokenError:
        raise ProblemException(
            status_code=401,
            title="Token Inválido",
            detail="Falha na decodificação do token JWT."
        )

def get_current_user(credentials: Optional[HTTPAuthorizationCredentials] = Security(security_bearer)) -> dict:
    if not credentials:
        raise ProblemException(
            status_code=401,
            title="Não Autenticado",
            detail="Cabeçalho de autorização Bearer ausente (CT-A02)."
        )
    return decode_token(credentials.credentials)

def require_roles(allowed_roles: List[str]):
    """
    Middleware RBAC para controle estrito de permissões (RF-02.2, RNF-18).
    Exemplo: Comprador tentando criar fornecimento -> 403 Forbidden.
    """
    def role_checker(user: dict = Depends(get_current_user)) -> dict:
        user_role = user.get("perfil")
        if user_role not in allowed_roles and "admin" not in user_role:
            raise ProblemException(
                status_code=403,
                title="Acesso Negado (RBAC)",
                detail=f"Perfil '{user_role}' não tem permissão para esta rota. Perfis autorizados: {allowed_roles}."
            )
        return user
    return role_checker
