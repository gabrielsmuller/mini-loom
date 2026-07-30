"""
Authentication via Amazon Cognito.

We no longer store passwords or sign our own tokens. A user signs in with
Google through Cognito's hosted UI; Cognito issues a signed JWT (an ID token).
This module's job is to VERIFY that token on each request:

  1. Cognito publishes its public signing keys (a "JWKS") at a well-known URL.
  2. We fetch those keys (cached), pick the one matching the token's `kid`
     header, and use it to check the token's signature, issuer, audience,
     and expiry.
  3. A valid token proves who the user is. We then get-or-create a local user
     row so videos can reference an owner (our relational model still holds).

Because verification uses Cognito's PUBLIC keys, the backend keeps no secret.
"""
import json
import logging
import urllib.request
from functools import lru_cache

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import User

logger = logging.getLogger("uvicorn.error")

# Where Cognito advertises the token issuer and its public keys.
_ISSUER = f"https://cognito-idp.{settings.aws_region}.amazonaws.com/{settings.cognito_user_pool_id}"
_JWKS_URL = f"{_ISSUER}/.well-known/jwks.json"

# Pulls the "Authorization: Bearer <token>" header off the request.
bearer = HTTPBearer(auto_error=True)


@lru_cache(maxsize=1)
def _jwks() -> dict:
    """Fetch Cognito's public signing keys once and cache them."""
    with urllib.request.urlopen(_JWKS_URL) as resp:
        return json.loads(resp.read())


def _verify_token(token: str) -> dict:
    """Return the token's claims if it's genuine; raise 401 otherwise."""
    credentials_error = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        # The token header names which key signed it; find that key.
        kid = jwt.get_unverified_header(token)["kid"]
        key = next(k for k in _jwks()["keys"] if k["kid"] == kid)
        # Verify signature + issuer + audience + expiry in one call.
        return jwt.decode(
            token,
            key,
            algorithms=["RS256"],
            audience=settings.cognito_client_id,
            issuer=_ISSUER,
            # ID tokens carry an at_hash that binds them to the access token.
            # We only use the ID token, so skip that optional cross-check
            # (signature, issuer, audience, and expiry are still verified).
            options={"verify_at_hash": False},
        )
    except Exception as e:  # log the real reason, then return a clean 401
        logger.warning(
            "Token verification failed: %s | issuer=%s audience=%s",
            e, _ISSUER, settings.cognito_client_id,
        )
        raise credentials_error


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer),
    db: Session = Depends(get_db),
) -> User:
    """FastAPI dependency: verify the token and return the local user row."""
    claims = _verify_token(creds.credentials)
    sub = claims.get("sub")            # Cognito's stable unique user id
    email = claims.get("email")
    if not sub:
        raise HTTPException(status_code=401, detail="Invalid token")

    # Provision a local user record on first sign-in (get-or-create).
    user = db.query(User).filter(User.id == sub).first()
    if user is None:
        user = User(id=sub, email=email)
        db.add(user)
        db.commit()
        db.refresh(user)
    return user
