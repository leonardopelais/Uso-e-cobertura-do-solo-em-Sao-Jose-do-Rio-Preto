import sys
sys.path.insert(0, "src")
from ingest_coverage import load
from db import get_connection


def test_load_coverage():
    load()
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT COUNT(DISTINCT geocode) FROM staging_coverage")
        assert cur.fetchone()[0] == 6
        cur.execute(
            "SELECT area_ha FROM staging_coverage "
            "WHERE geocode=3549805 AND class_level_2='4.2. Urban Area' AND year=2025"
        )
        area = cur.fetchone()[0]
        assert 10000 < area < 14000
    conn.close()
