from sqlalchemy.orm import Session
from app.crud.user import CRUDUser
from app.schemas.user import UserCreate, UserUpdate


class UserService:
    def __init__(self, db: Session):
        self.db = db
        self.crud_user = CRUDUser(db)

    # Example methods (will be implemented in future commits)
    def create_user(self, user_in: UserCreate):
        # Your logic here to create user via CRUDUser
        pass

    def get_user(self, user_id: int):
        # Your logic here to get user via CRUDUser
        pass

    def update_user(self, user_id: int, user_update: UserUpdate):
        # Your logic here to update user via CRUDUser
        pass

    def delete_user(self, user_id: int):
        # Your logic here to delete user via CRUDUser
        pass
