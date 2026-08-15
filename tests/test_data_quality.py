import sys
sys.path.insert(0, "src")
from db import get_connection


def test_no_orphan_coverage_rows():
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT COUNT(*) FROM staging_coverage sc
            LEFT JOIN dim_municipality dm ON dm.geocode = sc.geocode
            WHERE dm.geocode IS NULL
        """)
        assert cur.fetchone()[0] == 0
    conn.close()


def test_transition_area_matches_municipality_size():
    # este é o teste que teria pego, automaticamente, o erro real de
    # "território errado" que aconteceu durante a coleta manual dos dados
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("""
            SELECT SUM(area_ha) FROM fact_transition
            WHERE geocode = 3549805 AND period = '2015-2025'
        """)
        assert 42000 < cur.fetchone()[0] < 44000
    conn.close()
