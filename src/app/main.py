import time
import uuid
from contextlib import asynccontextmanager

import structlog
import structlog.contextvars
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from routers import user_router

from exceptions import AuthError
from logging_config import configure_logging

logger = structlog.get_logger(__name__)

_DESCRIPTION = """
## 認証フロー

1. `POST /api/auth/login` でトークンを取得する
2. 画面右上の **Authorize** ボタンをクリック
3. `access_token` の値を入力して **Authorize**
4. 以降のリクエストに `Bearer <token>` が自動付与される
"""

_TAGS = [
    {
        "name": "auth",
        "description": "認証・ユーザー管理",
    },
]


@asynccontextmanager
async def lifespan(_app: FastAPI):
    configure_logging()
    logger.info("starting up")
    yield
    logger.info("shutting down")


app = FastAPI(
    title="Azure Terraform Playground API",
    description=_DESCRIPTION,
    version="0.1.0",
    openapi_tags=_TAGS,
    lifespan=lifespan,
)


@app.middleware("http")
async def logging_middleware(request: Request, call_next):
    # リクエストごとに一意の ID を生成し、同一リクエスト内の全ログに自動付与する
    structlog.contextvars.clear_contextvars()
    structlog.contextvars.bind_contextvars(request_id=str(uuid.uuid4()))

    start = time.perf_counter()
    response = await call_next(request)
    duration_ms = round((time.perf_counter() - start) * 1000, 1)

    logger.info(
        "request",
        method=request.method,
        path=request.url.path,
        status_code=response.status_code,
        duration_ms=duration_ms,
    )
    return response


@app.exception_handler(AuthError)
async def auth_error_handler(_request: Request, exc: AuthError) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


app.include_router(user_router.router, prefix="/api")
