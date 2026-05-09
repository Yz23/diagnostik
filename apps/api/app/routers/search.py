from __future__ import annotations

from fastapi import APIRouter

from app.services.runtime import search_service
from diagnostik_common.schemas import SearchQuery, SearchResult, SearchType

router = APIRouter(tags=["search"])


@router.post("/search/text", response_model=list[SearchResult])
def search_text(query: SearchQuery) -> list[SearchResult]:
    query.search_type = SearchType.text
    return search_service.search(query)


@router.post("/search/vector", response_model=list[SearchResult])
def search_vector(query: SearchQuery) -> list[SearchResult]:
    query.search_type = SearchType.vector
    return search_service.search(query)


@router.post("/search/hybrid", response_model=list[SearchResult])
def search_hybrid(query: SearchQuery) -> list[SearchResult]:
    query.search_type = SearchType.hybrid
    return search_service.search(query)
