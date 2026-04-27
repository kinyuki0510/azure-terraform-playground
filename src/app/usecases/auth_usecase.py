from passlib.context import CryptContext

from repositories.user_repository import UserRepository
from schemas.user import TokenResponse
from utils.jwt import create_token

_pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


class AuthUsecase:
    def __init__(self, repo: UserRepository):
        self.repo = repo

    def register(self, name: str, email: str, password: str) -> TokenResponse:
        hashed = _pwd_context.hash(password)
        user = self.repo.create_user(name=name, email=email, hashed_password=hashed)
        return TokenResponse(access_token=create_token(user.id))

    def login(self, email: str, password: str) -> TokenResponse:
        user = self.repo.get_user_by_email(email)
        if not user or not _pwd_context.verify(password, user.password):
            raise ValueError("Invalid credentials")
        return TokenResponse(access_token=create_token(user.id))
