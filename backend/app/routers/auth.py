"""Auth endpoint. Login/register now happen in Cognito, so all that's left
here is a way for the frontend to fetch the current signed-in user."""
from fastapi import APIRouter, Depends

from app.models import User
from app.schemas import UserOut
from app.auth import get_current_user

router = APIRouter(prefix="/auth", tags=["auth"])


@router.get("/me", response_model=UserOut)
def me(user: User = Depends(get_current_user)):
    """Return the currently authenticated user (verified via Cognito token)."""
    return user
