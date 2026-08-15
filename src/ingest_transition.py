import csv
from pathlib import Path
from db import get_connection

TRANSITION_DIR = Path("dados brutos/transition")
SLUG_TO_MUNICIPALITY = {
    "sao-jose-do-rio-preto": "São José do Rio Preto",
    "mogi-das-cruzes": "Mogi das Cruzes",
    "jundiai": "Jundiaí",
    "piracicaba": "Piracicaba",
    "santos": "Santos",
    "maua": "Mauá",
}


def read_sankey_csv(path):
    rows = []
    with open(path, encoding="utf-8") as f:
        reader = csv.reader(f)
        next(reader)  # cabeçalho: "1985","1995","Área (ha)" (ou outro par de anos)
        for class_from, class_to, area_ha in reader:
            rows.append((class_from.strip('"'), class_to.strip('"'), float(area_ha)))
    return rows


def load():
    conn = get_connection()
    total = 0
    with conn, conn.cursor() as cur:
        cur.execute("TRUNCATE staging_transition")
        for slug, municipality in SLUG_TO_MUNICIPALITY.items():
            city_dir = TRANSITION_DIR / slug
            if not city_dir.exists():
                print(f"aviso: ainda não há dados de transição para {municipality} ({city_dir})")
                continue
            cur.execute("SELECT geocode FROM dim_municipality WHERE municipality = %s", (municipality,))
            row = cur.fetchone()
            if row is None:
                raise ValueError(
                    f"{municipality} não encontrado em dim_municipality — "
                    "rode a ingestão de população e sql/02_dimensions.sql antes desta"
                )
            geocode = row[0]
            for csv_path in sorted(city_dir.glob("*.csv")):
                period = csv_path.stem
                for class_from, class_to, area_ha in read_sankey_csv(csv_path):
                    cur.execute(
                        "INSERT INTO staging_transition "
                        "(geocode, municipality, period, class_from, class_to, area_ha) "
                        "VALUES (%s,%s,%s,%s,%s,%s)",
                        (geocode, municipality, period, class_from, class_to, area_ha),
                    )
                    total += 1
    conn.close()
    print(f"{total} linhas carregadas em staging_transition")


if __name__ == "__main__":
    load()
