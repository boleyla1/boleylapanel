from sqlalchemy.orm import Session


class ServerService:
    def __init__(self, db: Session):
        self.db = db
        # self.crud_server = CRUDServer(db) # Will add this when Server model/CRUD is ready

    # Placeholder for server-related business logic
    def get_all_servers(self):
        pass

    def add_server(self, server_data):
        pass
