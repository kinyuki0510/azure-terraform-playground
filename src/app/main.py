from contextlib import asynccontextmanager

from fastapi import FastAPI
from routers import user_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    print("Starting up...")
    yield
    print("Shutting down...")


app = FastAPI(lifespan=lifespan)

# _STATUS_MAP: dict[type[AppError], int] = {
#     DuplicateEmailError: 409,
#     AuthError: 401,
# }

# @app.exception_handler(AppError)
# async def app_error_handler(request: Request, exc: AppError) -> JSONResponse:
#     status_code = _STATUS_MAP.get(type(exc), 400)
#     return JSONResponse(status_code=status_code, content={"detail": str(exc)})


# @app.exception_handler(Exception)
# async def unknown_error_handler(request: Request, exc: Exception) -> JSONResponse:
#     return JSONResponse(status_code=500, content={"detail": "Internal server error"})

app.include_router(user_router.router, prefix="/api")
