from fastapi import APIRouter, Depends, HTTPException, status

from dependencies.deps import get_auth_usecase, get_current_user, require_auth
from models.user import User
from schemas.user import TokenResponse, UserLogin, UserRegister, UserResponse
from usecases.auth_usecase import AuthUsecase

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post(
    "/register", response_model=TokenResponse, status_code=status.HTTP_201_CREATED,
    dependencies=[Depends(require_auth)],
)
def register(body: UserRegister, usecase: AuthUsecase = Depends(get_auth_usecase)):
    try:
        return usecase.register(body.name, body.email, body.password)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))


@router.post("/login", response_model=TokenResponse)
def login(body: UserLogin, usecase: AuthUsecase = Depends(get_auth_usecase)):
    try:
        return usecase.login(body.email, body.password)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))


@router.get("/me", response_model=UserResponse)
def me(current_user: User = Depends(get_current_user)):
    return current_user
