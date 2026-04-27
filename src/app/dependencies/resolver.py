from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from functools import lru_cache

from config import get_settings
from dependencies.authenticator import Authenticator
from models.user import User
from repositories.session_manager import SessionManager
from repositories.user_repository import UserRepository
from usecases.auth_usecase import AuthUsecase
from usecases.user_usecase import UserUsecase


def get_bearer_security() -> HTTPBearer:
    return HTTPBearer()


@lru_cache
def get_session_manager() -> SessionManager:
    return SessionManager(get_settings())


def get_user_repository(
    session_manager: SessionManager = Depends(get_session_manager),
) -> UserRepository:
    return UserRepository(session_manager)


def get_auth_usecase(
    repo: UserRepository = Depends(get_user_repository),
) -> AuthUsecase:
    return AuthUsecase(repo)


def get_user_usecase(
    repo: UserRepository = Depends(get_user_repository),
) -> UserUsecase:
    return UserUsecase(repo)


def get_authenticator(
    credentials: HTTPAuthorizationCredentials = Depends(get_bearer_security),
    repo: UserRepository = Depends(get_user_repository),
) -> User:
    try:
        return Authenticator(repo).authenticate(credentials.credentials)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail=str(e))
