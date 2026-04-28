from fastapi import Depends
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from functools import lru_cache

from dependencies.authenticator import Authenticator
from models.user import User
from repositories.session_manager import SessionManager
from repositories.user_repository import UserRepository
from settings import get_settings
from usecases.auth_usecase import AuthUsecase
from usecases.user_usecase import UserUsecase


@lru_cache
def get_bearer_security() -> HTTPBearer:
    return HTTPBearer()


@lru_cache
def get_session_manager() -> SessionManager:
    return SessionManager(get_settings())


def get_user_repository(
    session_manager: SessionManager = Depends(get_session_manager),
) -> UserRepository:
    return UserRepository(session_manager)


def get_authenticator(
    repo: UserRepository = Depends(get_user_repository),
) -> Authenticator:
    return Authenticator(repo)


def get_auth_usecase(
    repo: UserRepository = Depends(get_user_repository),
) -> AuthUsecase:
    return AuthUsecase(repo)


def get_user_usecase(
    repo: UserRepository = Depends(get_user_repository),
) -> UserUsecase:
    return UserUsecase(repo)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(get_bearer_security()),
    authenticator: Authenticator = Depends(get_authenticator),
) -> User:
    return authenticator.authenticate(credentials.credentials)


def require_auth(
    _: User = Depends(get_current_user),
) -> None:
    pass
