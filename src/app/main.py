from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from routers import user_router

from exceptions import AuthError

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
async def lifespan(app: FastAPI):
    print("Starting up...")
    yield
    print("Shutting down...")


app = FastAPI(
    title="Azure Terraform Playground API",
    description=_DESCRIPTION,
    version="0.1.0",
    openapi_tags=_TAGS,
    lifespan=lifespan,
)


@app.exception_handler(AuthError)
async def auth_error_handler(_request: Request, exc: AuthError) -> JSONResponse:
    return JSONResponse(status_code=401, content={"detail": str(exc)})


app.include_router(user_router.router, prefix="/api")
