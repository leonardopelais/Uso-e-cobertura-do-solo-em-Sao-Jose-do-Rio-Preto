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
    return psycopg2.connect(**DB_CONFIG)
