import os
import psycopg2
from psycopg2 import pool
from contextlib import contextmanager
from typing import Generator, Optional
from .logger import setup_logger

logger = setup_logger("db-pool-manager")

DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "5432"))
DB_NAME = os.getenv("DB_NAME", "portal_b2b")
DB_USER = os.getenv("DB_USER", "portal_admin")
DB_PASSWORD = os.getenv("DB_PASSWORD", "postgres_master_dev_pass")
DB_POOL_MIN = int(os.getenv("DB_POOL_MIN", "1"))
DB_POOL_MAX = int(os.getenv("DB_POOL_MAX", "5")) # RNF-10: Limite estrito de 5 conexões por instância de serviço

_connection_pool: Optional[pool.SimpleConnectionPool] = None

def get_db_pool() -> Optional[pool.SimpleConnectionPool]:
    global _connection_pool
    if _connection_pool is None:
        try:
            _connection_pool = pool.SimpleConnectionPool(
                minconn=DB_POOL_MIN,
                maxconn=DB_POOL_MAX, # RNF-10
                host=DB_HOST,
                port=DB_PORT,
                dbname=DB_NAME,
                user=DB_USER,
                password=DB_PASSWORD,
                connect_timeout=3
            )
            logger.info(f"Pool PostgreSQL inicializado com sucesso (max {DB_POOL_MAX} conexoes - RNF-10).")
        except Exception as e:
            logger.warning(f"Banco PostgreSQL nao conectado ({e}). Operando com store em memoria/fallback.")
            return None
    return _connection_pool

@contextmanager
def get_db_connection() -> Generator:
    pool_instance = get_db_pool()
    if pool_instance:
        conn = pool_instance.getconn()
        try:
            yield conn
        finally:
            pool_instance.putconn(conn)
    else:
        yield None
