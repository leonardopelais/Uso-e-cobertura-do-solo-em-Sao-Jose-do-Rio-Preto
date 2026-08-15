import pandas as pd
from db import get_connection

XLSX_PATH = "dados brutos/MAPBIOMAS_BRAZIL-COL.11-BIOME_STATE_MUNICIPALITY.xlsx"
EXPECTED_ROWS = 77406
TARGET_MUNICIPALITIES = [
    "São José do Rio Preto", "Mogi das Cruzes", "Jundiaí",
    "Piracicaba", "Santos", "Mauá",
]
YEAR_COLUMNS = [f"y{y}" for y in range(1985, 2026)]
ID_COLUMNS = [
    "geocode", "municipality", "state",
    "class_level_0", "class_level_1", "class_level_2", "class_level_3", "class_level_4",
]


def read_filtered():
    df = pd.read_excel(XLSX_PATH, sheet_name="COVERAGE_11", engine="openpyxl")
    if len(df) != EXPECTED_ROWS:
        raise ValueError(f"esperado {EXPECTED_ROWS} linhas, veio {len(df)}")
    df = df[df["municipality"].isin(TARGET_MUNICIPALITIES) & (df["state"] == "São Paulo")]
    long_df = df.melt(id_vars=ID_COLUMNS, value_vars=YEAR_COLUMNS,
                       var_name="year_col", value_name="area_ha")
    long_df["year"] = long_df["year_col"].str[1:].astype(int)
    # municípios na fronteira de dois biomas aparecem em duas linhas por
    # classe/ano (uma por bioma) — soma pra granularidade ser só município
    return long_df.groupby(ID_COLUMNS + ["year"], as_index=False)["area_ha"].sum()


def load():
    long_df = read_filtered()
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("TRUNCATE staging_coverage")
        cur.executemany(
            "INSERT INTO staging_coverage "
            "(geocode, municipality, state, class_level_0, class_level_1, class_level_2, "
            "class_level_3, class_level_4, year, area_ha) VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
            long_df.values.tolist(),
        )
    conn.close()
    print(f"{len(long_df)} linhas carregadas em staging_coverage")


if __name__ == "__main__":
    load()
