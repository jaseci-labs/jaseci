"""
Diagnostic reporting framework for type checking.

Provides comprehensive error and warning reporting with location information.

Pyright Reference:
- Diagnostic handling concepts from analyzer/checker.ts
- Error reporting patterns from Pyright's diagnostic system
- Location tracking and severity levels
"""

from enum import Enum
from typing import Any, Dict, List, Optional, TYPE_CHECKING

import jaclang.compiler.unitree as uni

if TYPE_CHECKING:
    pass


class DiagnosticSeverity(Enum):
    """Severity levels for diagnostics."""

    ERROR = "error"
    WARNING = "warning"
    INFO = "info"
    HINT = "hint"


class TypeDiagnostic:
    """A type checking diagnostic message."""

    def __init__(
        self,
        message: str,
        severity: DiagnosticSeverity,
        node: Optional[uni.UniNode] = None,
        location: Optional[str] = None,
        error_code: Optional[str] = None,
    ) -> None:
        """Initialize a type diagnostic."""
        self.message = message
        self.severity = severity
        self.node = node
        self.location = location or self._extract_location(node)
        self.error_code = error_code

    def _extract_location(self, node: Optional[uni.UniNode]) -> str:
        """Extract location information from an AST node."""
        if node and hasattr(node, "loc") and node.loc:
            return f"line {node.loc.first_line}, col {node.loc.col_start}"
        elif node:
            return f"node {type(node).__name__}"
        else:
            return "unknown location"

    @classmethod
    def create_error(
        cls,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> "TypeDiagnostic":
        """Create an error diagnostic."""
        return cls(message, DiagnosticSeverity.ERROR, node, None, error_code)

    @classmethod
    def create_warning(
        cls,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> "TypeDiagnostic":
        """Create a warning diagnostic."""
        return cls(message, DiagnosticSeverity.WARNING, node, None, error_code)

    @classmethod
    def create_info(
        cls,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> "TypeDiagnostic":
        """Create an info diagnostic."""
        return cls(message, DiagnosticSeverity.INFO, node, None, error_code)

    def __str__(self) -> str:
        """Return string representation of the diagnostic."""
        location_str = f" at {self.location}" if self.location else ""
        error_code_str = f" [{self.error_code}]" if self.error_code else ""
        return f"{self.severity.value.upper()}: {self.message}{location_str}{error_code_str}"

    def __repr__(self) -> str:
        """Detailed string representation of the diagnostic."""
        return (
            f"TypeDiagnostic(message='{self.message}', "
            f"severity={self.severity.value}, "
            f"location='{self.location}', "
            f"error_code={self.error_code})"
        )

    def to_dict(self) -> Dict[str, Any]:
        """Convert diagnostic to dictionary format."""
        return {
            "message": self.message,
            "severity": self.severity.value,
            "location": self.location,
            "error_code": self.error_code,
        }


class DiagnosticSink:
    """Collect and manage type checking diagnostics."""

    def __init__(self) -> None:
        """Initialize the diagnostic sink."""
        self.diagnostics: List[TypeDiagnostic] = []

    def add_diagnostic(self, diagnostic: TypeDiagnostic) -> None:
        """Add a diagnostic to the sink."""
        self.diagnostics.append(diagnostic)

    def add_error(
        self,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> None:
        """Add an error diagnostic."""
        self.add_diagnostic(TypeDiagnostic.create_error(message, node, error_code))

    def add_warning(
        self,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> None:
        """Add a warning diagnostic."""
        self.add_diagnostic(TypeDiagnostic.create_warning(message, node, error_code))

    def add_info(
        self,
        message: str,
        node: Optional[uni.UniNode] = None,
        error_code: Optional[str] = None,
    ) -> None:
        """Add an info diagnostic."""
        self.add_diagnostic(TypeDiagnostic.create_info(message, node, error_code))

    def get_diagnostics(self) -> List[TypeDiagnostic]:
        """Get all collected diagnostics."""
        return self.diagnostics.copy()

    def get_errors(self) -> List[TypeDiagnostic]:
        """Get only error diagnostics."""
        return [d for d in self.diagnostics if d.severity == DiagnosticSeverity.ERROR]

    def get_warnings(self) -> List[TypeDiagnostic]:
        """Get only warning diagnostics."""
        return [d for d in self.diagnostics if d.severity == DiagnosticSeverity.WARNING]

    def has_errors(self) -> bool:
        """Check if there are any error diagnostics."""
        return any(d.severity == DiagnosticSeverity.ERROR for d in self.diagnostics)

    def clear(self) -> None:
        """Clear all diagnostics."""
        self.diagnostics.clear()

    def filter_by_severity(self, severity: DiagnosticSeverity) -> List[TypeDiagnostic]:
        """Filter diagnostics by severity level."""
        return [d for d in self.diagnostics if d.severity == severity]

    def filter_by_error_code(self, error_code: str) -> List[TypeDiagnostic]:
        """Filter diagnostics by error code."""
        return [d for d in self.diagnostics if d.error_code == error_code]

    def get_summary(self) -> Dict[str, int]:
        """Return a summary of diagnostic counts by severity."""
        summary = {severity.value: 0 for severity in DiagnosticSeverity}
        for diagnostic in self.diagnostics:
            summary[diagnostic.severity.value] += 1
        return summary

    def print_diagnostics(self, max_count: Optional[int] = None) -> None:
        """Print all diagnostics to console."""
        diagnostics_to_print = self.diagnostics
        if max_count:
            diagnostics_to_print = diagnostics_to_print[:max_count]

        for diagnostic in diagnostics_to_print:
            print(diagnostic)

        if max_count and len(self.diagnostics) > max_count:
            remaining = len(self.diagnostics) - max_count
            print(f"... and {remaining} more diagnostics")

    def __len__(self) -> int:
        """Return the number of diagnostics."""
        return len(self.diagnostics)

    def __str__(self) -> str:
        """Return string representation of the diagnostic sink."""
        summary = self.get_summary()
        return f"DiagnosticSink({summary})"

    def __repr__(self) -> str:
        """Detailed string representation of the diagnostic sink."""
        return f"DiagnosticSink(total={len(self.diagnostics)}, summary={self.get_summary()})"


# Common error codes for type checking
class TypeErrorCodes:
    """Provide standard error codes for type checking diagnostics."""

    UNDEFINED_SYMBOL = "T001"
    TYPE_MISMATCH = "T002"
    INCOMPATIBLE_ASSIGNMENT = "T003"
    INVALID_OPERATION = "T004"
    FUNCTION_CALL_ERROR = "T005"
    ATTRIBUTE_ERROR = "T006"
    INDEX_ERROR = "T007"
    ARGUMENT_ERROR = "T008"
    RETURN_TYPE_MISMATCH = "T009"
    UNREACHABLE_CODE = "T010"
