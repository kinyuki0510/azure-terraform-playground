from sqlalchemy.exc import IntegrityError

from session_manager import SessionManager

from ..models.user import User


class UserRepository:
    def __init__(self, session_manager: SessionManager):
        self._session_manager = session_manager

    def get_user_by_id(self, user_id: int) -> User | None:
        with self._session_manager.get_session() as session:
            return session.query(User).filter(User.id == user_id).first()

    def get_user_by_email(self, email: str) -> User | None:
        with self._session_manager.get_session() as session:
            return session.query(User).filter(User.email == email).first()

    def create_user(self, name: str, email: str, hashed_password: str) -> User:
        try:
            with self._session_manager.get_session() as session:
                user = User(name=name, email=email, password=hashed_password)
                session.add(user)
                return user
        except IntegrityError:
            # raise DuplicateEmailError(f"Email already registered: {email}")
            raise ValueError(f"Email already registered: {email}")
