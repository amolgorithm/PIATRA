"""
Fixes the "five chicken stir-fries" problem: ranking by quality score alone
returns near-duplicate recipes, because near-duplicates score similarly
well by definition. This runs a greedy selection instead, at each step
picking whichever remaining candidate has the best quality minus how
correlated it already is with what's been picked so far. Same intuition as
building a portfolio where you don't want three assets that all move
together (Markowitz-style diversification), just a greedy heuristic instead
of solving that exactly, which is what makes this cheap enough to run on
every request instead of needing an optimizer.

Reuses two things that already exist elsewhere in this codebase: quality
scores come from the client's own ranking engine (stage 2 of the original
recipe pipeline), and each recipe's vector is built from its nutrient
profile the same way Feature 3 built per-ingredient vectors, protein/fat/
carbs/etc, z-scored, compared by cosine similarity.
"""

import numpy as np

from app.models.diversity import DiversifyRequest, DiversifiedItem, DiversifyResponse

_NUTRIENT_KEYS = [
    "calories", "protein_g", "carbs_g", "fat_g",
    "fiber_g", "sugar_g", "sodium_mg",
]


def _build_vectors(req: DiversifyRequest) -> np.ndarray:
    raw = np.array(
        [[c.nutrients.get(k, 0.0) for k in _NUTRIENT_KEYS] for c in req.candidates],
        dtype=float,
    )
    mean = raw.mean(axis=0)
    std = raw.std(axis=0)
    std[std == 0] = 1.0
    return (raw - mean) / std


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def diversify(req: DiversifyRequest) -> DiversifyResponse:
    candidates = req.candidates
    n = len(candidates)
    if n == 0:
        return DiversifyResponse(selected=[])

    k = min(req.k, n)
    vectors = _build_vectors(req)

    selected_idx: list[int] = []
    selected_items: list[DiversifiedItem] = []
    remaining = set(range(n))

    while len(selected_idx) < k and remaining:
        best_idx = None
        best_score = float("-inf")
        best_avg_sim = 0.0

        for j in remaining:
            if selected_idx:
                sims = [_cosine_similarity(vectors[j], vectors[s]) for s in selected_idx]
                avg_sim = sum(sims) / len(sims)
            else:
                avg_sim = 0.0  # first pick, nothing to be similar to yet

            score = candidates[j].quality - req.alpha * avg_sim
            if score > best_score:
                best_score = score
                best_idx = j
                best_avg_sim = avg_sim

        selected_idx.append(best_idx)
        remaining.discard(best_idx)
        c = candidates[best_idx]
        selected_items.append(DiversifiedItem(
            id=c.id,
            name=c.name,
            quality=c.quality,
            avg_similarity_at_pick=round(best_avg_sim, 3),
        ))

    return DiversifyResponse(selected=selected_items)
