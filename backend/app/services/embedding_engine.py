"""
Ingredient substitution as a vector-space nearest-neighbor problem. Each
ingredient is a point in nutrient space (protein, fat, carbs, fiber, sugar
per 100g), "what's a good substitute for X" becomes "what's closest to X's
vector," measured with cosine similarity. That's the core feature and it's
pure first-year linear algebra: dot products and vector norms, nothing more.

The optional embedding-map function projects that same vector space down to
2D so it can actually be plotted, that's the one piece here that's a notch
ahead of the rest of this plan (eigendecomposition of a covariance matrix),
flagged as such, and implemented by hand with numpy rather than importing
scikit-learn for something this small.
"""

import json
import os

import numpy as np

_DATA_PATH = os.path.join(os.path.dirname(__file__), "..", "data", "ingredient_nutrients.json")
_NUTRIENT_KEYS = ["protein_g", "fat_g", "carbs_g", "fiber_g", "sugar_g"]

_cache = None


def _load():
    global _cache
    if _cache is not None:
        return _cache

    with open(_DATA_PATH) as f:
        raw = json.load(f)

    names = [k for k in raw.keys() if isinstance(raw[k], dict)]  # skip the _comment key
    matrix = np.array([[raw[n][k] for k in _NUTRIENT_KEYS] for n in names], dtype=float)

    # z-score each nutrient column before comparing anything. carbs run
    # 0-70g and fiber runs 0-34g, without this a raw dot product would be
    # dominated by whichever nutrient happens to have the biggest numbers,
    # not whichever nutrients actually make two ingredients similar
    mean = matrix.mean(axis=0)
    std = matrix.std(axis=0)
    std[std == 0] = 1.0
    normalized = (matrix - mean) / std

    _cache = {"names": names, "raw": matrix, "normalized": normalized}
    return _cache


def _cosine_similarity(a: np.ndarray, b: np.ndarray) -> float:
    denom = np.linalg.norm(a) * np.linalg.norm(b)
    if denom == 0:
        return 0.0
    return float(np.dot(a, b) / denom)


def find_substitutes(ingredient_name: str, limit: int = 5):
    """
    Returns (results, close_matches). results is None if the name wasn't
    found exactly, in which case close_matches has a few names that contain
    or are contained by the query, so the caller can suggest "did you mean."
    """
    data = _load()
    names = data["names"]
    lower_names = [n.lower() for n in names]
    query = ingredient_name.strip().lower()

    if query not in lower_names:
        close = [n for n in names if query in n.lower() or n.lower() in query]
        return None, close[:5]

    idx = lower_names.index(query)
    query_vec = data["normalized"][idx]

    scored = []
    for i, name in enumerate(names):
        if i == idx:
            continue
        sim = _cosine_similarity(query_vec, data["normalized"][i])
        scored.append((name, sim))

    scored.sort(key=lambda x: x[1], reverse=True)
    return scored[:limit], None


def embedding_map():
    """
    PCA down to 2D via eigendecomposition of the covariance matrix, by hand,
    not sklearn.decomposition.PCA. Project onto the two directions of
    largest variance in the nutrient data, that's the whole idea, everything
    else here is bookkeeping.
    """
    data = _load()
    X = data["normalized"]
    X_centered = X - X.mean(axis=0)

    cov = np.cov(X_centered, rowvar=False)
    eigvals, eigvecs = np.linalg.eigh(cov)  # ascending order
    order = np.argsort(eigvals)[::-1][:2]   # take the 2 largest-variance directions
    top_vecs = eigvecs[:, order]

    coords = X_centered @ top_vecs

    return [
        {"name": data["names"][i], "x": round(float(coords[i, 0]), 3), "y": round(float(coords[i, 1]), 3)}
        for i in range(len(data["names"]))
    ]
