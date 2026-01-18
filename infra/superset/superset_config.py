import os

# Database connection
SQLALCHEMY_DATABASE_URI = os.environ.get(
    "SQLALCHEMY_DATABASE_URI",
    "postgresql://superset:superset@superset-postgres:5432/superset"
)

# Redis cache
REDIS_HOST = os.environ.get("REDIS_HOST", "superset-redis")
REDIS_PORT = os.environ.get("REDIS_PORT", 6379)

CACHE_CONFIG = {
    "CACHE_TYPE": "RedisCache",
    "CACHE_DEFAULT_TIMEOUT": 300,
    "CACHE_KEY_PREFIX": "superset_",
    "CACHE_REDIS_HOST": REDIS_HOST,
    "CACHE_REDIS_PORT": REDIS_PORT,
    "CACHE_REDIS_DB": 1,
}

# Security
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "changeme")

# Feature flags
FEATURE_FLAGS = {
    "ENABLE_TEMPLATE_PROCESSING": True,
}

# Allow embedding in iframes (optional, for dashboards)
HTTP_HEADERS = {"X-Frame-Options": "ALLOWALL"}
