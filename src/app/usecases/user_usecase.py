from repositories.user_repository import UserRepository
from schemas.user import UserResponse


class UserUsecase:
    def __init__(self, user_repository: UserRepository):
        self._user_repository = user_repository

    def get_user_by_id(self, user_id: int) -> UserResponse | None:
        user = self._user_repository.get_user_by_id(user_id)
        if user is None:
            return None
        return UserResponse.model_validate(user)

    def get_user_by_email(self, email: str) -> UserResponse | None:
        user = self._user_repository.get_user_by_email(email)
        if user is None:
            return None
        return UserResponse.model_validate(user)
