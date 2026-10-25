from typing import Optional, Any, Dict
from fastapi import Request, HTTPException, status
from fastapi.responses import JSONResponse
from .logger import correlation_id_ctx

class ProblemException(HTTPException):
    """
    Exceção base compatível com RFC 7807 (CT-A03).
    """
    def __init__(
        self,
        status_code: int,
        title: str,
        detail: str,
        problem_type: str = "about:blank",
        instance: Optional[str] = None,
        extra: Optional[Dict[str, Any]] = None
    ):
        super().__init__(status_code=status_code, detail=detail)
        self.title = title
        self.problem_type = problem_type
        self.instance = instance
        self.extra = extra or {}

def create_problem_response(
    status_code: int,
    title: str,
    detail: str,
    instance: str,
    problem_type: str = "about:blank",
    extra: Optional[Dict[str, Any]] = None
) -> JSONResponse:
    corr_id = correlation_id_ctx.get() or "none"
    content = {
        "type": problem_type,
        "title": title,
        "status": status_code,
        "detail": detail,
        "instance": instance,
        "correlationId": corr_id
    }
    if extra:
        content.update(extra)

    return JSONResponse(
        status_code=status_code,
        content=content,
        headers={"Content-Type": "application/problem+json"}
    )

async def problem_exception_handler(request: Request, exc: ProblemException) -> JSONResponse:
    return create_problem_response(
        status_code=exc.status_code,
        title=exc.title,
        detail=exc.detail,
        instance=exc.instance or request.url.path,
        problem_type=exc.problem_type,
        extra=exc.extra
    )
