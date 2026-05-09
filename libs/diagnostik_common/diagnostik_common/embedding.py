from __future__ import annotations

import hashlib
import math
from abc import ABC, abstractmethod


class EmbeddingProvider(ABC):
    model_name: str
    model_version: str
    dimension: int

    @abstractmethod
    def embed_text(self, text: str) -> list[float]:
        raise NotImplementedError


class MockEmbeddingProvider(EmbeddingProvider):
    model_name = "mock-hash-embedding"
    model_version = "1"
    dimension = 32

    def embed_text(self, text: str) -> list[float]:
        digest = hashlib.sha256(text.encode("utf-8")).digest()
        vector = [((byte / 255.0) * 2.0) - 1.0 for byte in digest[: self.dimension]]
        norm = math.sqrt(sum(value * value for value in vector)) or 1.0
        return [round(value / norm, 6) for value in vector]
