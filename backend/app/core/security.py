"""
Clerk JWT Token Verification

This module verifies JWT tokens issued by Clerk using JWKS (JSON Web Key Set).
Clerk uses RS256 (RSA) algorithm, not HS256.

The PyJWKClient handles JWKS caching internally - it fetches keys once and reuses them,
and refetches if it encounters an unknown key ID (handles Clerk key rotation automatically).
"""

import jwt
from jwt import PyJWKClient, PyJWKClientError
from app.core.config import settings

# Initialize the JWKS client - this fetches and caches Clerk's public keys
_jwks_client: PyJWKClient | None = None


def get_jwks_client() -> PyJWKClient:
    """Get or create the JWKS client for Clerk token verification."""
    global _jwks_client
    if _jwks_client is None:
        if not settings.CLERK_JWKS_URL:
            raise ValueError("CLERK_JWKS_URL is not configured in environment variables")
        _jwks_client = PyJWKClient(settings.CLERK_JWKS_URL)
    return _jwks_client


def verify_clerk_token(token: str) -> dict:
    """
    Verify a Clerk session token and return the decoded payload.
    
    Args:
        token: The JWT token from the Authorization header
        
    Returns:
        The decoded JWT payload containing claims like:
        - sub: Clerk user ID (e.g., "user_2Qbkhxfu7VCmvM4Xguez0fmMg1c")
        - email: User's email (if custom claims configured)
        - name: User's name (if custom claims configured)
        - iat: Issued at timestamp
        - exp: Expiration timestamp
        
    Raises:
        jwt.InvalidTokenError: If token is invalid, expired, or signature doesn't match
        jwt.PyJWKClientError: If there's an issue fetching JWKS
        ValueError: If Clerk is not configured
    """
    if not settings.CLERK_JWT_ISSUER:
        raise ValueError("CLERK_JWT_ISSUER is not configured in environment variables")
    
    jwks_client = get_jwks_client()
    
    # Get the signing key from Clerk's JWKS
    # This handles key rotation automatically - if key ID is unknown, it refetches
    signing_key = jwks_client.get_signing_key_from_jwt(token)
    
    # Decode and verify the token
    # - Verifies the RS256 signature using Clerk's public key
    # - Verifies the token hasn't expired
    # - Verifies the issuer matches our Clerk instance
    payload = jwt.decode(
        token,
        signing_key.key,
        algorithms=["RS256"],
        issuer=settings.CLERK_JWT_ISSUER,
        options={
            "verify_signature": True,
            "verify_exp": True,
            "verify_iss": True,
            "require": ["sub", "exp", "iat"]
        }
    )
    
    return payload
