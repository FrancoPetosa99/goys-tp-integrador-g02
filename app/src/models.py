from datetime import datetime

from pydantic import BaseModel, Field


class CategoryIn(BaseModel):
    name: str = Field(min_length=1, max_length=200)
    description: str | None = None


class CategoryOut(BaseModel):
    id: int
    name: str
    description: str | None = None
    created_at: datetime


class CategoryWithCount(CategoryOut):
    product_count: int


class ProductIn(BaseModel):
    category_id: int
    name: str = Field(min_length=1, max_length=200)
    price: float = Field(ge=0)
    stock: int = Field(ge=0, default=0)


class ProductUpdate(BaseModel):
    price: float = Field(ge=0)
    stock: int = Field(ge=0)


class ProductOut(BaseModel):
    id: int
    category_id: int
    name: str
    price: float
    stock: int
    created_at: datetime
    updated_at: datetime


class ProductWithCategory(ProductOut):
    category_name: str


class Page(BaseModel):
    items: list
    limit: int
    offset: int
    total: int
