"""
Standardized error messages for API responses.

This module provides consistent, user-friendly error messages across all API endpoints.
Using constants ensures uniformity and makes it easier to update messaging.
"""


class ErrorMessages:
    """Constants for API error messages."""

    # ============================================================================
    # Authentication Errors
    # ============================================================================
    AUTH_TOKEN_EXPIRED = "Authentication token has expired. Please sign in again."
    AUTH_INVALID_TOKEN = "Invalid authentication token. Please sign in again."
    AUTH_MISSING_SUBJECT = "Authentication token is malformed. Please sign in again."
    AUTH_MISSING_EMAIL = "User email not found in authentication token. Please contact support."
    AUTH_FAILED = "Authentication failed. Please sign in again."

    # ============================================================================
    # Authorization Errors
    # ============================================================================
    AUTHZ_RESOURCE_NOT_FOUND = "Resource not found or you don't have access."

    # ============================================================================
    # Validation Errors
    # ============================================================================
    VALIDATION_DUPLICATE_NAME = "A resource with this name already exists."
    VALIDATION_REQUIRED_FIELD = "Required field is missing."

    # ============================================================================
    # Resource Errors
    # ============================================================================
    RESOURCE_LIST_NOT_FOUND = "List not found."
    RESOURCE_RESTAURANT_NOT_FOUND = "Restaurant not found."
    RESOURCE_RESTAURANT_NOT_SAVED = "Restaurant not saved by user."
    RESOURCE_SAVE_EVENT_NOT_FOUND = "Save event not found."

    # ============================================================================
    # Server Errors
    # ============================================================================
    SERVER_ERROR = "An unexpected error occurred. Please try again."
    SERVER_DELETE_FAILED = "Failed to delete resource. Please try again."

    # ============================================================================
    # Deprecated Endpoints
    # ============================================================================
    ENDPOINT_FAVORITES_GONE = "Gone. Use GET /home instead — favorites are returned as is_favorite flags on each restaurant."
    ENDPOINT_VISITED_GONE = "Gone. Use GET /home instead — visited status is returned as is_visited flags on each restaurant."


class ErrorCodes:
    """
    Machine-readable error codes for client-side handling.

    These can be included in response headers (X-Error-Code) to allow
    iOS/web clients to handle specific error cases programmatically.
    """

    # Auth codes
    TOKEN_EXPIRED = "TOKEN_EXPIRED"
    TOKEN_INVALID = "TOKEN_INVALID"
    TOKEN_MALFORMED = "TOKEN_MALFORMED"
    TOKEN_MISSING_EMAIL = "TOKEN_MISSING_EMAIL"

    # Resource codes
    RESOURCE_NOT_FOUND = "RESOURCE_NOT_FOUND"
    DUPLICATE_RESOURCE = "DUPLICATE_RESOURCE"

    # Server codes
    INTERNAL_ERROR = "INTERNAL_ERROR"
