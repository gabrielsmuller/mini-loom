"""
Database connection setup.

This backend connects to Postgres two different ways, chosen by config:

  - Locally and in tests: a normal SQLAlchemy connection over TCP (psycopg to a
    local Postgres, or SQLite for the test suite). This is the default.

  - In AWS (use_data_api=True): the RDS Data API — SQL sent to Aurora over
    HTTPS, so the Lambda never enters the VPC and we avoid a NAT Gateway. Same
    SQLAlchemy models and queries; only the engine's connection differs.

Aurora Serverless pauses to zero ACUs when idle and takes ~15s to resume. For
the TCP path, pool_pre_ping + a connect timeout survive that pause/resume. The
Data API is stateless HTTP, so it sidesteps the stale-connection problem
entirely — there's no long-lived socket to go bad.
"""
import time

from sqlalchemy import create_engine, text
from sqlalchemy.orm import declarative_base, sessionmaker

from app.config import settings

if settings.use_data_api:
    # SQL-over-HTTPS to Aurora. The URL carries only the database name; the
    # cluster and secret ARNs (from Terraform outputs) go in connect_args.
    engine = create_engine(
        f"postgresql+auroradataapi://:@/{settings.aurora_database_name}",
        connect_args={
            "aurora_cluster_arn": settings.aurora_cluster_arn,
            "secret_arn": settings.aurora_secret_arn,
        },
    )
else:
    # Normal TCP connection (local Postgres, or SQLite in tests). The
    # connect_timeout arg is Postgres-only; SQLite rejects it.
    _connect_args = {}
    if settings.database_url.startswith("postgresql"):
        _connect_args["connect_timeout"] = 20

    engine = create_engine(
        settings.database_url,
        pool_pre_ping=True,          # survive Aurora pause/resume cycles
        pool_recycle=280,            # recycle connections before idle timeouts
        connect_args=_connect_args,  # wait out the ~15s cold start (Postgres only)
    )

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# Whether tables have been ensured for this (warm) Lambda container / process.
_initialized = False


def _resume_retry(fn, retries: int = 12, delay: float = 3.0):
    """
    Run fn(), retrying while Aurora Serverless is resuming from auto-pause.

    A paused cluster answers the first Data API call with
    DatabaseResumingException while it wakes (~15-25s); we retry until it's up.
    Any other error is raised immediately. Non-Aurora paths (local Postgres,
    SQLite) never see this exception, so fn() just succeeds on the first try.
    """
    last_error = None
    for _ in range(retries):
        try:
            return fn()
        except Exception as e:
            if "resuming" in str(e).lower():
                last_error = e
                time.sleep(delay)
                continue
            raise
    raise last_error


def init_db() -> None:
    """Create tables (once per container), waiting out an Aurora resume."""
    from app import models  # noqa: F401 — ensure tables are registered on Base

    _resume_retry(lambda: Base.metadata.create_all(bind=engine))


def _ensure_awake(db) -> None:
    """
    Block until Aurora has resumed, on EVERY request — not just the first.

    The container can stay warm long after Aurora re-pauses (5 min idle), so a
    later request's real query would otherwise fail immediately. A cheap
    `SELECT 1` with resume-retry guarantees the cluster is up before the
    endpoint runs its queries. When Aurora is already awake this is one fast
    round-trip; locally (SQLite/Postgres) it always succeeds instantly.
    """
    def _ping():
        try:
            db.execute(text("SELECT 1"))
        except Exception:
            db.rollback()  # clear the failed transaction before retrying
            raise

    _resume_retry(_ping)


def get_db():
    """FastAPI dependency that yields a database session per request."""
    global _initialized
    db = SessionLocal()
    try:
        if not _initialized:
            init_db()
            _initialized = True
        _ensure_awake(db)
        yield db
    finally:
        db.close()
