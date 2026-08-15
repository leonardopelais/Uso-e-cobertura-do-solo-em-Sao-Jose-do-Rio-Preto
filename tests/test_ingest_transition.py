import sys
sys.path.insert(0, "src")
from ingest_transition import load
from db import get_connection


def test_load_transition_sjrp():
    load()
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("SELECT DISTINCT period FROM staging_transition WHERE geocode = 3549805")
        periods = {r[0] for r in cur.fetchall()}
        assert periods == {"1985-1995", "1995-2005", "2005-2015", "2015-2025"}
        cur.execute(
            "SELECT SUM(area_ha) FROM staging_transition "
            "WHERE geocode = 3549805 AND period = '2015-2025'"
        )
        assert 42000 < cur.fetchone()[0] < 44000
    conn.close()
