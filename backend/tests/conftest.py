"""
Test fixtures. We override the database with a local SQLite file so tests
run anywhere with no AWS or PostgreSQL needed, and set dummy Cognito values
(token verification itself is bypassed in tests via a dependency override).
"""
import os

# Fresh schema each run: remove any leftover SQLite file so create_all builds
# the current tables (the models changed when we moved to Cognito).
if os.path.exists("test.db"):
    os.remove("test.db")

os.environ["DATABASE_URL"] = "sqlite+pysqlite:///./test.db"
os.environ["VIDEO_BUCKET"] = "test-bucket"
os.environ["COGNITO_USER_POOL_ID"] = "us-east-1_test"
os.environ["COGNITO_CLIENT_ID"] = "test-client"
