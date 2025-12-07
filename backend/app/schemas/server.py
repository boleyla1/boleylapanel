from pydantic import BaseModel
from typing import Optional


class ServerBase(BaseModel):
    name: str
    address: str
    port: int
    is_active: bool = True


class ServerCreate(ServerBase):
    pass


class ServerUpdate(BaseModel):
    name: Optional[str] = None
    address: Optional[str] = None
    port: Optional[int] = None
    is_active: Optional[bool] = None


class ServerResponse(ServerBase):
    id: int

    class Config:
        from_attributes = True


class ServerOut(ServerBase):
    id: int

    class Config:
        from_attributes = True


class ServerInDB(ServerBase):
    id: int

    class Config:
        from_attributes = True
