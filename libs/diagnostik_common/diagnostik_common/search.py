from __future__ import annotations

from diagnostik_common.embedding import EmbeddingProvider, MockEmbeddingProvider
from diagnostik_common.schemas import SearchQuery, SearchResult, SearchType
from diagnostik_common.storage import InMemoryStore


def _matches_filters(metadata: dict, filters: dict) -> bool:
    tags = filters.get("tags")
    if tags:
        doc_tags = set(metadata.get("tags", []))
        if not set(tags).issubset(doc_tags):
            return False
    return True


class SearchService:
    def __init__(self, store: InMemoryStore, embedding_provider: EmbeddingProvider | None = None) -> None:
        self.store = store
        self.embedding_provider = embedding_provider or MockEmbeddingProvider()

    def search(self, query: SearchQuery) -> list[SearchResult]:
        results: list[SearchResult] = []
        query_terms = {term.lower() for term in query.query.split() if term.strip()}
        query_vector = self.embedding_provider.embed_text(query.query)

        for document in self.store.documents.values():
            dataset = self.store.datasets.get(document.dataset_id)
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
                embedding = self.store.embeddings.get(document.embedding_ids[-1])
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
