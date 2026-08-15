import xlrd
from db import get_connection

XLS_PATH = "dados brutos/IBGE_POP2025_MUNICIPIOS.xls"
EXPECTED_SP_ROWS = 645


def read_sp_rows():
    wb = xlrd.open_workbook(XLS_PATH)
    sheet = wb.sheet_by_name("Municípios")
    rows = []
    for r in range(2, sheet.nrows):
        uf, uf_code, mun_code, name, pop, _ = [sheet.cell_value(r, c) for c in range(6)]
        if uf == "SP":
            uf_code = int(float(uf_code))
            mun_code = int(float(mun_code))
            geocode = uf_code * 100000 + mun_code
            rows.append((uf, uf_code, mun_code, geocode, name, int(pop)))
    return rows


def load():
    rows = read_sp_rows()
    if len(rows) != EXPECTED_SP_ROWS:
        raise ValueError(f"esperado {EXPECTED_SP_ROWS} municípios de SP, veio {len(rows)}")
    conn = get_connection()
    with conn, conn.cursor() as cur:
        cur.execute("TRUNCATE staging_population")
        cur.executemany(
            "INSERT INTO staging_population "
            "(state, uf_code, municipality_code, geocode, municipality, population) "
            "VALUES (%s,%s,%s,%s,%s,%s)",
            rows,
        )
    conn.close()
    print(f"{len(rows)} municípios de SP carregados em staging_population")


if __name__ == "__main__":
    load()
