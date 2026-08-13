from fastapi import APIRouter, HTTPException

from app.models.embedding import SubstitutesResponse, SubstituteResult, EmbeddingMapResponse, EmbeddingPoint
from app.services.embedding_engine import find_substitutes, embedding_map

router = APIRouter()


@router.get("/{name}/substitutes", response_model=SubstitutesResponse)
async def get_substitutes(name: str, limit: int = 5):
    """Nearest neighbors of an ingredient in nutrient-vector space, by cosine similarity."""
    results, close_matches = find_substitutes(name, limit=limit)

    if results is None:
        detail = "ingredient not in the nutrient cache"
        if close_matches:
            detail += f", did you mean one of: {', '.join(close_matches)}?"
        raise HTTPException(status_code=404, detail=detail)

    return SubstitutesResponse(
        query=name,
        substitutes=[SubstituteResult(name=n, similarity=round(s, 3)) for n, s in results],
    )


@router.get("/embedding-map", response_model=EmbeddingMapResponse)
async def get_embedding_map():
    """2D PCA projection of the whole ingredient nutrient space, for visualization."""
    points = embedding_map()
    return EmbeddingMapResponse(points=[EmbeddingPoint(**p) for p in points])
