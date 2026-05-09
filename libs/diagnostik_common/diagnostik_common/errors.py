class DiagnostikError(Exception):
    """Base exception for domain errors."""


class ConnectorError(DiagnostikError):
    """Connector validation or execution failed."""


class PipelineError(DiagnostikError):
    """Pipeline validation or execution failed."""


class SearchError(DiagnostikError):
    """Search backend or query error."""
