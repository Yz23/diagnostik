from __future__ import annotations

from typing import Protocol

from diagnostik_common.config import RuntimeMode
from diagnostik_common.embedding import EmbeddingProvider, MockEmbeddingProvider
from diagnostik_common.opensearch import build_text_query
from diagnostik_common.schemas import SearchQuery, SearchResult, SearchType
from diagnostik_common.storage import MetadataStore


def _matches_filters(metadata: dict, filters: dict) -> bool:
    tags = filters.get("tags")
    if tags:
        doc_tags = set(metadata.get("tags", []))
        if not set(tags).issubset(doc_tags):
            return False
    return True


class SearchBackend(Protocol):
    def search(
        self,
        query: SearchQuery,
        store: MetadataStore,
        embedding_provider: EmbeddingProvider,
    ) -> list[SearchResult]: ...


class InMemorySearchBackend:
    def search(
        self,
        query: SearchQuery,
        store: MetadataStore,
        embedding_provider: EmbeddingProvider,
    ) -> list[SearchResult]:
        results: list[SearchResult] = []
        query_terms = {term.lower() for term in query.query.split() if term.strip()}
        query_vector = embedding_provider.embed_text(query.query)

        for document in store.documents.values():
            dataset = store.datasets.get(document.dataset_id)
            if dataset is None or dataset.workspace_id != query.workspace_id:
                continue
            if query.dataset_ids and document.dataset_id not in query.dataset_ids:
                continue
            if not _matches_filters({**document.metadata, "tags": dataset.tags}, query.filters):
                continue

            text = f"{document.title} {document.text}".lower()
            text_score = sum(1 for term in query_terms if term in text) / max(len(query_terms), 1)
            vector_score = 0.0
            if document.embedding_ids:
                embedding = store.embeddings.get(document.embedding_ids[-1])
                if embedding:
                    vector_score = sum(a * b for a, b in zip(query_vector, embedding.vector, strict=False))
            if query.search_type == SearchType.text:
                score = text_score
            elif query.search_type == SearchType.vector:
                score = vector_score
            else:
                score = (query.alpha * vector_score) + ((1.0 - query.alpha) * text_score)
            if score > 0:
                results.append(
                    SearchResult(
                        document_id=document.id,
                        dataset_id=document.dataset_id,
                        title=document.title,
                        text=document.text,
                        score=round(score, 6),
                        metadata=document.metadata,
                    )
                )
        return sorted(results, key=lambda item: item.score, reverse=True)[: query.limit]


class OpenSearchSearchBackend:
    """OpenSearch search contract for the MVP runtime."""

    def __init__(self, endpoint: str, index: str) -> None:
        self.endpoint = endpoint.rstrip("/")
        self.index = index

    def build_query(self, query: SearchQuery) -> dict:
        return build_text_query(query.workspace_id, query.query, query.dataset_ids)

    def search(
        self,
        query: SearchQuery,
        store: MetadataStore,
        embedding_provider: EmbeddingProvider,
    ) -> list[SearchResult]:
        raise NotImplementedError("OpenSearch search backend is planned for MVP; use DIAGNOSTIK_RUNTIME=memory for POC.")


def create_search_backend(runtime: RuntimeMode, opensearch_url: str, documents_index: str) -> SearchBackend:
    if runtime == RuntimeMode.opensearch:
        return OpenSearchSearchBackend(opensearch_url, documents_index)
    return InMemorySearchBackend()


class SearchService:
    def __init__(
        self,
        store: MetadataStore,
        embedding_provider: EmbeddingProvider | None = None,
        backend: SearchBackend | None = None,
    ) -> None:
        self.store = store
        self.embedding_provider = embedding_provider or MockEmbeddingProvider()
        self.backend = backend or InMemorySearchBackend()

    def search(self, query: SearchQuery) -> list[SearchResult]:
        return self.backend.search(query, self.store, self.embedding_provider)
