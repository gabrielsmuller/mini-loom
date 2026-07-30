from fastapi.testclient import TestClient


def _app_and_client():
    # Imported inside the function so conftest env vars are set first.
    from app.main import app
    return app, TestClient(app)


def _override_user(app):
    """Bypass real Cognito token verification in tests by returning a fake
    signed-in user. We can't (and shouldn't) mint real Cognito tokens here, so
    we override the dependency directly."""
    from app.auth import get_current_user
    from app.models import User

    app.dependency_overrides[get_current_user] = lambda: User(
        id="test-sub", email="tester@example.com"
    )


def test_health():
    _, client = _app_and_client()
    r = client.get("/health")
    assert r.status_code == 200
    assert r.json()["status"] == "ok"


def test_auth_me_returns_current_user():
    app, client = _app_and_client()
    _override_user(app)

    r = client.get("/auth/me")
    assert r.status_code == 200
    assert r.json()["email"] == "tester@example.com"
    assert r.json()["id"] == "test-sub"


def test_list_videos_empty_for_new_user():
    app, client = _app_and_client()
    _override_user(app)

    r = client.get("/videos")
    assert r.status_code == 200
    assert r.json() == []
