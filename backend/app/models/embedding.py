from pydantic import BaseModel
from typing import List, Optional


class SubstituteResult(BaseModel):
    name: str
    similarity: float  # cosine similarity, -1 to 1, higher is closer


class SubstitutesResponse(BaseModel):
    query: str
    substitutes: List[SubstituteResult]


class EmbeddingPoint(BaseModel):
    name: str
    x: float
    y: float


class EmbeddingMapResponse(BaseModel):
    points: List[EmbeddingPoint]
