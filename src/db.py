import os
import psycopg2
from db_config import PASSWORD

DB_CONFIG = dict(
    host="localhost",
    port=5432,
    dbname="riopreto",
    user="postgres",
    password=PASSWORD,
)


def get_connection():
    if os.environ.get("USE_NEON"):
        from neon_config import DATABASE_URL
        return psycopg2.connect(DATABASE_URL)
    return psycopg2.connect(**DB_CONFIG)
