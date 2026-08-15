import sys
sys.path.insert(0, "src")
from ingest_population import load
from db import get_connection


def test_load_population():
    load()
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(*) FROM staging_population")
        assert cur.fetchone()[0] == 645
        cur.execute("SELECT population FROM staging_population WHERE geocode = 3549805")
        assert cur.fetchone()[0] == 504166
    conn.close()
