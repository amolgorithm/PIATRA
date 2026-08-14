from pydantic import BaseModel
from typing import List, Dict


class DiversityCandidate(BaseModel):
    id: str
    name: str
    quality: float               # relevance/quality score from the client's own ranking
    nutrients: Dict[str, float]   # same shape Feature 1/3 use, becomes the recipe's vector


class DiversifyRequest(BaseModel):
    candidates: List[DiversityCandidate]
    k: int = 5          # how many to keep
    # how hard to penalize similarity to what's already picked. tuned by
    # testing against a mock "4 near-identical recipes + 3 different ones"
    # case: alpha below ~2 barely changes anything when quality gaps are in
    # the 1-10 point range (typical for this app's 0-100 scoring), alpha
    # around 5-8 is where genuinely different picks start beating
    # near-duplicates. 6.0 sits in that validated range.
    alpha: float = 6.0


class DiversifiedItem(BaseModel):
    id: str
    name: str
    quality: float
    avg_similarity_at_pick: float  # how correlated with the already-picked set, at pick time


class DiversifyResponse(BaseModel):
    selected: List[DiversifiedItem]
