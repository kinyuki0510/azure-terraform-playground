from models.user import User
from repositories.user_repository import UserRepository
from utils.jwt import decode_token


class Authenticator:
    def __init__(self, repo: UserRepository):
        self._repo = repo

    def authenticate(self, token: str) -> User:
        try:
            user_id = decode_token(token)
        except ValueError:
            raise ValueError("Invalid token")
        user = self._repo.get_user_by_id(user_id)
        if not user:
            raise ValueError("User not found")
        return user
