# Uso e Cobertura do Solo em Rio Preto — Plano de Implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Construir o pipeline Python → PostgreSQL → gráficos que responde as 8 perguntas do spec sobre expansão urbana de São José do Rio Preto (1985–2025).

**Architecture:** Staging (espelho do bruto) → dimensões/fatos (modelo dimensional) → views (uma por pergunta) → gráficos. Ingestão em Python, modelagem e análise em SQL puro.

**Tech Stack:** Python 3.14 (pandas, psycopg2-binary, xlrd, matplotlib, pytest), PostgreSQL local.

**Spec:** `docs/specs/2026-08-15-uso-cobertura-solo-rio-preto-design.md`

## Global Constraints

- Staging nunca sofre transformação de negócio — só formato (largo→longo).
- Grupo de comparação: São José do Rio Preto (`geocode` 3549805) + Mogi das Cruzes, Jundiaí, Piracicaba, Santos, Mauá.
- Todo texto em PT; nomes de tabela/coluna/variável em EN.
- Dados brutos nunca vão para o Git (já coberto por `.gitignore`).
- Cada script de ingestão valida contagem de linhas esperada antes de gravar (Camada 1 do spec).

---

### Task 1: Ambiente

**Files:** nenhum arquivo de código — instalação e verificação.

- [ ] **Passo 1: Instalar PostgreSQL**

Baixe o instalador em https://www.postgresql.org/download/windows/ e rode-o. Na tela de senha do superusuário `postgres`, escolha uma senha e **anote** — vai ser usada no `db.py` da Task 3. Mantenha a porta padrão `5432`.

- [ ] **Passo 2: Criar o banco do projeto**

```bash
psql -U postgres -c "CREATE DATABASE riopreto;"
```

- [ ] **Passo 3: Verificar a conexão**

```bash
psql -U postgres -d riopreto -c "SELECT 1;"
```

Esperado: retorna `1` numa tabela, sem erro.

- [ ] **Passo 4: Instalar as bibliotecas Python**

```bash
pip install pandas psycopg2-binary xlrd openpyxl matplotlib pytest
```

- [ ] **Passo 5: Criar a estrutura de pastas**

```bash
cd "projeto uso e cobertura do solo - riopreto"
mkdir -p src sql tests outputs/figuras "dados brutos/transition"
```

---

### Task 2: Schema do banco

**Files:**
- Create: `sql/01_schema.sql`

**Interfaces:**
- Produces: tabelas `staging_population`, `staging_coverage`, `staging_transition`, `dim_municipality`, `dim_class`, `fact_coverage`, `fact_transition` — nomes de coluna usados por todas as tasks seguintes.

- [ ] **Passo 1: Escrever o schema**

```sql
-- sql/01_schema.sql

-- Staging: espelho fiel do dado bruto, sem transformação de negócio
CREATE TABLE staging_population (
    state              TEXT NOT NULL,
    uf_code            INTEGER NOT NULL,
    municipality_code  INTEGER NOT NULL,
    geocode            INTEGER NOT NULL,
    municipality       TEXT NOT NULL,
    population         INTEGER NOT NULL
);

CREATE TABLE staging_coverage (
    geocode        INTEGER NOT NULL,
    municipality   TEXT NOT NULL,
    state          TEXT NOT NULL,
    class_level_0  TEXT NOT NULL,
    class_level_1  TEXT,
    class_level_2  TEXT,
    class_level_3  TEXT,
    class_level_4  TEXT,
    year           INTEGER NOT NULL,
    area_ha        NUMERIC NOT NULL
);

CREATE TABLE staging_transition (
    geocode       INTEGER NOT NULL,
    municipality  TEXT NOT NULL,
    period        TEXT NOT NULL,
    class_from    TEXT NOT NULL,
    class_to      TEXT NOT NULL,
    area_ha       NUMERIC NOT NULL
);

-- Dimensões
CREATE TABLE dim_municipality (
    geocode              INTEGER PRIMARY KEY,
    municipality         TEXT NOT NULL,
    state                TEXT NOT NULL,
    population           INTEGER NOT NULL,
    is_comparison_group  BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE TABLE dim_class (
    class_id       SERIAL PRIMARY KEY,
    class_level_0  TEXT NOT NULL,
    class_level_1  TEXT,
    class_level_2  TEXT,
    class_level_3  TEXT,
    class_level_4  TEXT,
    class_name     TEXT NOT NULL UNIQUE  -- nível mais profundo disponível; é o que aparece no TRANSITION
);

-- Fatos
CREATE TABLE fact_coverage (
    geocode   INTEGER NOT NULL REFERENCES dim_municipality(geocode),
    class_id  INTEGER NOT NULL REFERENCES dim_class(class_id),
    year      INTEGER NOT NULL,
    area_ha   NUMERIC NOT NULL,
    PRIMARY KEY (geocode, class_id, year)
);

CREATE TABLE fact_transition (
    geocode        INTEGER NOT NULL REFERENCES dim_municipality(geocode),
    class_id_from  INTEGER NOT NULL REFERENCES dim_class(class_id),
    class_id_to    INTEGER NOT NULL REFERENCES dim_class(class_id),
    period         TEXT NOT NULL,
    area_ha        NUMERIC NOT NULL,
    PRIMARY KEY (geocode, class_id_from, class_id_to, period)
);
```

- [ ] **Passo 2: Rodar o schema**

```bash
psql -U postgres -d riopreto -f sql/01_schema.sql
```

- [ ] **Passo 3: Verificar**

```bash
psql -U postgres -d riopreto -c "\dt"
```

Esperado: lista as 7 tabelas acima.

- [ ] **Passo 4: Commit**

```bash
git add sql/01_schema.sql
git commit -m "feat: schema do banco (staging, dimensões, fatos)"
```

---

### Task 3: Conexão compartilhada e dependências

**Files:**
- Create: `src/db.py`
- Create: `requirements.txt`

**Interfaces:**
- Produces: `db.get_connection() -> psycopg2.connection`, usado por todos os scripts de ingestão e por `charts.py`.

- [ ] **Passo 1: Criar `src/db.py`**

```python
import psycopg2

DB_CONFIG = dict(
    host="localhost",
    port=5432,
    dbname="riopreto",
    user="postgres",
    password="TROQUE_PELA_SUA_SENHA",  # a senha que você definiu na Task 1
)


def get_connection():
    return psycopg2.connect(**DB_CONFIG)
```

Troque `TROQUE_PELA_SUA_SENHA` pela senha real que você escolheu ao instalar o PostgreSQL.

- [ ] **Passo 2: Criar `requirements.txt`**

```
pandas
psycopg2-binary
xlrd
openpyxl
matplotlib
pytest
```

- [ ] **Passo 3: Verificar**

```bash
python -c "import sys; sys.path.insert(0,'src'); from db import get_connection; get_connection(); print('conexão ok')"
```

- [ ] **Passo 4: Commit**

```bash
git add src/db.py requirements.txt
git commit -m "feat: conexão compartilhada com o banco"
```

---

### Task 4: Ingestão — população

**Files:**
- Create: `src/ingest_population.py`
- Test: `tests/test_ingest_population.py`

**Interfaces:**
- Consumes: `db.get_connection()` (Task 3), tabela `staging_population` (Task 2).
- Produces: `ingest_population.load()` — carrega `staging_population`; usado depois pela Task 7 (dimensões).

- [ ] **Passo 1: Escrever o teste**

```python
# tests/test_ingest_population.py
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
```

- [ ] **Passo 2: Rodar o teste e ver que falha**

```bash
pytest tests/test_ingest_population.py -v
```

Esperado: FAIL — `ModuleNotFoundError: No module named 'ingest_population'`.

- [ ] **Passo 3: Escrever `src/ingest_population.py`**

```python
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
```

- [ ] **Passo 4: Rodar o teste e ver que passa**

```bash
pytest tests/test_ingest_population.py -v
```

Esperado: PASS.

- [ ] **Passo 5: Commit**

```bash
git add src/ingest_population.py tests/test_ingest_population.py
git commit -m "feat: ingestão da população IBGE"
```

---

### Task 5: Ingestão — COVERAGE

**Files:**
- Create: `src/ingest_coverage.py`
- Test: `tests/test_ingest_coverage.py`

**Interfaces:**
- Consumes: `db.get_connection()`, tabela `staging_coverage`.
- Produces: `ingest_coverage.load()` — carrega `staging_coverage` **já em formato longo**, filtrado às 6 cidades do grupo.

Filtra às 6 cidades na ingestão (não em staging "puro Brasil") porque o arquivo bruto é 75 MB / 5.580 municípios e nunca vamos precisar dos outros 5.574 — carregar tudo só deixaria o banco lento à toa.

- [ ] **Passo 1: Escrever o teste**

```python
# tests/test_ingest_coverage.py
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
            "WHERE geocode=3549805 AND class_level_4='Área Urbanizada' AND year=2025"
        )
        area = cur.fetchone()[0]
        assert 10000 < area < 14000
    conn.close()
```

- [ ] **Passo 2: Rodar o teste e ver que falha**

```bash
pytest tests/test_ingest_coverage.py -v
```

Esperado: FAIL — `ModuleNotFoundError`.

- [ ] **Passo 3: Escrever `src/ingest_coverage.py`**

```python
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
    return long_df[ID_COLUMNS + ["year", "area_ha"]]


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
```

- [ ] **Passo 4: Rodar o teste e ver que passa**

```bash
pytest tests/test_ingest_coverage.py -v
```

Esperado: PASS. (Pode demorar 1–2 min — o arquivo é grande.)

- [ ] **Passo 5: Commit**

```bash
git add src/ingest_coverage.py tests/test_ingest_coverage.py
git commit -m "feat: ingestão do MapBiomas COVERAGE (formato longo, 6 cidades)"
```

---

### Task 6: Reorganizar e ingerir TRANSITION

**Files:**
- Create: `src/ingest_transition.py`
- Test: `tests/test_ingest_transition.py`
- Move: os 4 CSVs de SJRP já baixados

**Interfaces:**
- Consumes: `db.get_connection()`, tabela `dim_municipality` **já populada** (Task 7 precisa rodar antes deste script funcionar de fato — mas o teste/commit desta task só valida a leitura de arquivo + lógica, então documentamos a ordem real de execução no fim do plano).
- Produces: `ingest_transition.load()` — carrega `staging_transition`; convenção de pastas para os próximos exports manuais.

**Convenção de arquivos** (documentar isso é o entregável mais importante desta task): cada cidade tem sua própria subpasta em `dados brutos/transition/<slug>/`, com um CSV por período nomeado `<período>.csv`. Isso é necessário porque os arquivos que a Plataforma do MapBiomas gera **não indicam o município no nome** — a única forma de saber de qual cidade é cada export é onde você o guarda.

| Cidade | slug da pasta |
|---|---|
| São José do Rio Preto | `sao-jose-do-rio-preto` |
| Mogi das Cruzes | `mogi-das-cruzes` |
| Jundiaí | `jundiai` |
| Piracicaba | `piracicaba` |
| Santos | `santos` |
| Mauá | `maua` |

- [ ] **Passo 1: Reorganizar os 4 arquivos de SJRP já baixados**

```bash
cd "dados brutos"
mkdir -p transition/sao-jose-do-rio-preto
mv "Diagrama de Sankey 1985-1995.csv" transition/sao-jose-do-rio-preto/1985-1995.csv
mv "Diagrama de Sankey 1995-2005.csv" transition/sao-jose-do-rio-preto/1995-2005.csv
mv "Diagrama de Sankey 2005-2015.csv" transition/sao-jose-do-rio-preto/2005-2015.csv
mv "Diagrama de Sankey 2015-2025.csv" transition/sao-jose-do-rio-preto/2015-2025.csv
cd ..
```

(`Diagrama de Sankey (1).csv` e o arquivo `Cobertura • Transições...csv` ficam onde estão — não entram no pipeline, foram só exploração.)

Para as próximas 5 cidades: ao exportar cada período na Plataforma, mova o CSV baixado para `dados brutos/transition/<slug>/<período>.csv`, usando a tabela de slugs acima e período no formato `1985-1995`, `1995-2005`, `2005-2015`, `2015-2025`.

- [ ] **Passo 2: Escrever o teste**

```python
# tests/test_ingest_transition.py
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
```

- [ ] **Passo 3: Rodar o teste e ver que falha**

```bash
pytest tests/test_ingest_transition.py -v
```

Esperado: FAIL — `ModuleNotFoundError`.

- [ ] **Passo 4: Escrever `src/ingest_transition.py`**

```python
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
```

- [ ] **Passo 5: Rodar `sql/01_schema.sql` + população + dimensões antes do teste**

Este script depende de `dim_municipality` já ter São José do Rio Preto. Rode, nesta ordem, antes do passo 6:

```bash
python src/ingest_population.py
```

(a Task 7 cria `dim_municipality` — se ela ainda não rodou, volte aqui depois de completá-la)

- [ ] **Passo 6: Rodar o teste e ver que passa**

```bash
pytest tests/test_ingest_transition.py -v
```

Esperado: PASS.

- [ ] **Passo 7: Commit**

```bash
git add src/ingest_transition.py tests/test_ingest_transition.py "dados brutos/transition"
git commit -m "feat: ingestão do MapBiomas TRANSITION + convenção de pastas por cidade"
```

Note que `dados brutos/` está no `.gitignore` — o `git add` acima é um no-op proposital para os CSVs (eles não vão ao Git); o que importa deste commit é o script.

---

### Task 7: Popular dimensões

**Files:**
- Create: `sql/02_dimensions.sql`

**Interfaces:**
- Consumes: `staging_population` (Task 4), `staging_coverage` (Task 5).
- Produces: `dim_municipality` e `dim_class` populadas — usadas pelas Tasks 6 (ordem real), 8 e 9.

**Ordem real de execução** (ajuste ao rodar o projeto do zero):
`01_schema.sql` → `ingest_population.py` → **este arquivo** → `ingest_coverage.py` → `ingest_transition.py` → `03_facts.sql`.

- [ ] **Passo 1: Escrever `sql/02_dimensions.sql`**

```sql
-- sql/02_dimensions.sql

-- dim_municipality: todos os municípios de SP entram (dado já é pequeno),
-- mas só os 6 do grupo de comparação ficam marcados is_comparison_group = TRUE.
-- A regra usa a própria tabela para achar as 5 populações mais próximas de SJRP —
-- não é uma lista fixa de nomes.
INSERT INTO dim_municipality (geocode, municipality, state, population)
SELECT DISTINCT geocode, municipality, state, population
FROM staging_population;

UPDATE dim_municipality
SET is_comparison_group = TRUE
WHERE geocode = 3549805
   OR geocode IN (
        SELECT geocode
        FROM dim_municipality
        WHERE geocode != 3549805
        ORDER BY ABS(population - (SELECT population FROM dim_municipality WHERE geocode = 3549805))
        LIMIT 5
   );

-- dim_class: uma linha por combinação única de níveis, vinda do COVERAGE.
-- class_name = nível mais profundo disponível — é o mesmo texto que aparece
-- nos exports de TRANSITION (Sankey), por isso serve de chave de JOIN entre os dois.
INSERT INTO dim_class (class_level_0, class_level_1, class_level_2, class_level_3, class_level_4, class_name)
SELECT DISTINCT ON (COALESCE(class_level_4, class_level_3, class_level_2, class_level_1, class_level_0))
    class_level_0, class_level_1, class_level_2, class_level_3, class_level_4,
    COALESCE(class_level_4, class_level_3, class_level_2, class_level_1, class_level_0)
FROM staging_coverage;
```

- [ ] **Passo 2: Rodar**

```bash
psql -U postgres -d riopreto -f sql/02_dimensions.sql
```

- [ ] **Passo 3: Verificar**

```bash
psql -U postgres -d riopreto -c "SELECT municipality, population, is_comparison_group FROM dim_municipality WHERE is_comparison_group ORDER BY population DESC;"
```

Esperado: 6 linhas — São José do Rio Preto, Mogi das Cruzes, Jundiaí, Piracicaba, Santos, Mauá.

```bash
psql -U postgres -d riopreto -c "SELECT class_name FROM dim_class WHERE class_name = 'Área Urbanizada';"
```

Esperado: 1 linha.

- [ ] **Passo 4: Commit**

```bash
git add sql/02_dimensions.sql
git commit -m "feat: popula dim_municipality (regra de população) e dim_class"
```

---

### Task 8: Popular fatos + validação de qualidade

**Files:**
- Create: `sql/03_facts.sql`
- Test: `tests/test_data_quality.py`

**Interfaces:**
- Consumes: `staging_coverage`, `staging_transition`, `dim_municipality`, `dim_class` (todas populadas).
- Produces: `fact_coverage`, `fact_transition` populadas — usadas pela Task 9 (views).

- [ ] **Passo 1: Escrever `sql/03_facts.sql`**

```sql
-- sql/03_facts.sql

INSERT INTO fact_coverage (geocode, class_id, year, area_ha)
SELECT sc.geocode, dc.class_id, sc.year, sc.area_ha
FROM staging_coverage sc
JOIN dim_class dc
  ON dc.class_name = COALESCE(sc.class_level_4, sc.class_level_3, sc.class_level_2, sc.class_level_1, sc.class_level_0);

INSERT INTO fact_transition (geocode, class_id_from, class_id_to, period, area_ha)
SELECT st.geocode, dcf.class_id, dct.class_id, st.period, st.area_ha
FROM staging_transition st
JOIN dim_class dcf ON dcf.class_name = st.class_from
JOIN dim_class dct ON dct.class_name = st.class_to;

-- Validação (Camada 2 do spec): nenhuma linha de staging deve ficar sem
-- município correspondente depois do JOIN. Se a query abaixo retornar
-- alguma linha, algo está errado (ex.: geocode com erro de digitação).
SELECT sc.geocode, sc.municipality
FROM staging_coverage sc
LEFT JOIN dim_municipality dm ON dm.geocode = sc.geocode
WHERE dm.geocode IS NULL;
```

- [ ] **Passo 2: Rodar**

```bash
psql -U postgres -d riopreto -f sql/03_facts.sql
```

Esperado: a última query (validação) não retorna nenhuma linha.

- [ ] **Passo 3: Escrever o teste de qualidade**

```python
# tests/test_data_quality.py
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
```

- [ ] **Passo 4: Rodar o teste**

```bash
pytest tests/test_data_quality.py -v
```

Esperado: PASS.

- [ ] **Passo 5: Commit**

```bash
git add sql/03_facts.sql tests/test_data_quality.py
git commit -m "feat: popula fact_coverage/fact_transition + testes de qualidade"
```

---

### Task 9: Views de análise

**Files:**
- Create: `sql/04_views_analise.sql`

**Interfaces:**
- Consumes: `fact_coverage`, `fact_transition`, `dim_municipality`, `dim_class`.
- Produces: as 8 views abaixo — usadas pela Task 10 (`charts.py`).

- [ ] **Passo 1: Escrever `sql/04_views_analise.sql`**

```sql
-- sql/04_views_analise.sql

-- 1. Evolução da área urbana de SJRP, ano a ano
CREATE VIEW vw_urban_growth_sjrp AS
SELECT fc.year, fc.area_ha
FROM fact_coverage fc
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE fc.geocode = 3549805 AND dc.class_name = 'Área Urbanizada'
ORDER BY fc.year;

-- 2. Ritmo de crescimento comparado às 5 cidades do grupo
CREATE VIEW vw_urban_growth_comparison AS
SELECT dm.municipality, fc.year, fc.area_ha,
       ROUND(100.0 * (fc.area_ha - FIRST_VALUE(fc.area_ha) OVER w)
             / FIRST_VALUE(fc.area_ha) OVER w, 1) AS growth_pct
FROM fact_coverage fc
JOIN dim_municipality dm ON dm.geocode = fc.geocode
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE dm.is_comparison_group AND dc.class_name = 'Área Urbanizada'
WINDOW w AS (PARTITION BY dm.geocode ORDER BY fc.year)
ORDER BY dm.municipality, fc.year;

-- 3. O que virou área urbana em SJRP, por década
CREATE VIEW vw_transition_to_urban_sjrp AS
SELECT ft.period, dcf.class_name AS origin_class, SUM(ft.area_ha) AS area_ha
FROM fact_transition ft
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE ft.geocode = 3549805 AND dct.class_name = 'Área Urbanizada' AND dcf.class_name <> 'Área Urbanizada'
GROUP BY ft.period, dcf.class_name
ORDER BY ft.period, area_ha DESC;

-- 4. % da área urbana nova vinda de pastagem, por período (SJRP)
CREATE VIEW vw_share_pastagem_by_period AS
SELECT DISTINCT
    period,
    SUM(area_ha) FILTER (WHERE origin_class = 'Pastagem') OVER (PARTITION BY period) AS pastagem_ha,
    SUM(area_ha) OVER (PARTITION BY period) AS total_ha,
    ROUND(100.0 * SUM(area_ha) FILTER (WHERE origin_class = 'Pastagem') OVER (PARTITION BY period)
          / SUM(area_ha) OVER (PARTITION BY period), 1) AS pastagem_pct
FROM vw_transition_to_urban_sjrp;

-- 5. O mesmo padrão, nas 5 cidades de comparação
CREATE VIEW vw_share_pastagem_by_city AS
SELECT DISTINCT
    dm.municipality,
    ft.period,
    SUM(ft.area_ha) FILTER (WHERE dcf.class_name = 'Pastagem')
        OVER (PARTITION BY dm.municipality, ft.period) AS pastagem_ha,
    SUM(ft.area_ha) OVER (PARTITION BY dm.municipality, ft.period) AS total_ha,
    ROUND(100.0 * SUM(ft.area_ha) FILTER (WHERE dcf.class_name = 'Pastagem')
        OVER (PARTITION BY dm.municipality, ft.period)
        / SUM(ft.area_ha) OVER (PARTITION BY dm.municipality, ft.period), 1) AS pastagem_pct
FROM fact_transition ft
JOIN dim_municipality dm ON dm.geocode = ft.geocode
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE dm.is_comparison_group AND dct.class_name = 'Área Urbanizada' AND dcf.class_name <> 'Área Urbanizada';

-- 6. Ranking: quem converteu mais pastagem em área urbana
CREATE VIEW vw_ranking_pastagem_to_urban AS
SELECT dm.municipality,
       SUM(ft.area_ha) AS pastagem_to_urban_ha,
       RANK() OVER (ORDER BY SUM(ft.area_ha) DESC) AS rank_absoluto
FROM fact_transition ft
JOIN dim_municipality dm ON dm.geocode = ft.geocode
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE dm.is_comparison_group AND dcf.class_name = 'Pastagem' AND dct.class_name = 'Área Urbanizada'
GROUP BY dm.municipality;

-- 7. Composição agrícola de SJRP ao longo dos 41 anos
CREATE VIEW vw_agri_composition_over_time AS
SELECT dc.class_name, fc.year, fc.area_ha
FROM fact_coverage fc
JOIN dim_class dc ON dc.class_id = fc.class_id
WHERE fc.geocode = 3549805
  AND dc.class_name IN ('Pastagem','Cana','Soja','Café','Citrus','Silvicultura','Mosaico de Usos')
ORDER BY dc.class_name, fc.year;

-- 8. Transições entre classes agrícolas (não só para urbano), por período
CREATE VIEW vw_agri_transitions_by_period AS
SELECT ft.period, dcf.class_name AS origin_class, dct.class_name AS destination_class,
       SUM(ft.area_ha) AS area_ha
FROM fact_transition ft
JOIN dim_class dcf ON dcf.class_id = ft.class_id_from
JOIN dim_class dct ON dct.class_id = ft.class_id_to
WHERE ft.geocode = 3549805
  AND dcf.class_name IN ('Pastagem','Cana','Soja','Café','Citrus','Silvicultura','Mosaico de Usos')
  AND dct.class_name IN ('Pastagem','Cana','Soja','Café','Citrus','Silvicultura','Mosaico de Usos')
  AND dcf.class_name <> dct.class_name
GROUP BY ft.period, dcf.class_name, dct.class_name
ORDER BY ft.period, area_ha DESC;
```

- [ ] **Passo 2: Rodar**

```bash
psql -U postgres -d riopreto -f sql/04_views_analise.sql
```

- [ ] **Passo 3: Verificar cada view com uma consulta simples**

```bash
psql -U postgres -d riopreto -c "SELECT * FROM vw_share_pastagem_by_period;"
```

Esperado: 4 linhas (uma por década), `pastagem_pct` caindo ao longo do tempo (84 → 78 → 77 → 56, aproximadamente — os números batem com o que já vimos manualmente).

- [ ] **Passo 4: Commit**

```bash
git add sql/04_views_analise.sql
git commit -m "feat: 8 views de análise (perguntas do spec)"
```

---

### Task 10: Gráficos

**Files:**
- Create: `src/charts.py`

**Interfaces:**
- Consumes: `db.get_connection()`, views `vw_urban_growth_comparison` e `vw_share_pastagem_by_period`.
- Produces: `outputs/figuras/urban_growth_comparison.png`, `outputs/figuras/share_pastagem_by_period.png` — usados no README (Task 11).

Só 2 gráficos por enquanto — os dois que carregam a tese central do projeto (ritmo de crescimento comparado, e a queda da dependência de pastagem). Mais gráficos das outras views entram depois, sem precisar replanejar nada.

- [ ] **Passo 1: Escrever `src/charts.py`**

```python
import pandas as pd
import matplotlib.pyplot as plt
from db import get_connection

OUT_DIR = "outputs/figuras"


def chart_urban_growth_comparison():
    conn = get_connection()
    df = pd.read_sql("SELECT * FROM vw_urban_growth_comparison", conn)
    conn.close()
    fig, ax = plt.subplots()
    for municipality, group in df.groupby("municipality"):
        ax.plot(group["year"], group["growth_pct"], label=municipality)
    ax.set_xlabel("Ano")
    ax.set_ylabel("Crescimento da área urbana (%)")
    ax.set_title("Crescimento da área urbana — SJRP vs. cidades de porte similar")
    ax.legend(fontsize="small")
    fig.savefig(f"{OUT_DIR}/urban_growth_comparison.png", dpi=150, bbox_inches="tight")


def chart_share_pastagem_by_period():
    conn = get_connection()
    df = pd.read_sql("SELECT * FROM vw_share_pastagem_by_period", conn)
    conn.close()
    fig, ax = plt.subplots()
    ax.bar(df["period"], df["pastagem_pct"])
    ax.set_ylabel("% da área urbana nova vinda de pastagem")
    ax.set_title("SJRP: dependência de pastagem na expansão urbana, por década")
    fig.savefig(f"{OUT_DIR}/share_pastagem_by_period.png", dpi=150, bbox_inches="tight")


if __name__ == "__main__":
    chart_urban_growth_comparison()
    chart_share_pastagem_by_period()
    print("gráficos salvos em outputs/figuras/")
```

- [ ] **Passo 2: Rodar**

```bash
python src/charts.py
```

- [ ] **Passo 3: Verificar**

```bash
ls outputs/figuras/
```

Esperado: os dois arquivos `.png` listados. Abra-os para conferir visualmente.

- [ ] **Passo 4: Commit**

```bash
git add src/charts.py outputs/figuras/*.png
git commit -m "feat: gráficos de crescimento urbano e origem da expansão"
```

---

### Task 11: README

**Files:**
- Create: `README.md`
- Create: `README.en.md`

**Interfaces:**
- Consumes: os PNGs da Task 10, os achados documentados no spec (Seção 5).

- [ ] **Passo 1: Escrever `README.md`**

Estrutura mínima (adapte o texto, mas mantenha as seções):

```markdown
# Uso e Cobertura do Solo em São José do Rio Preto (1985–2025)

Como a mancha urbana de São José do Rio Preto cresceu nos últimos 40 anos, o que ela
substituiu, e como isso se compara a cidades paulistas de porte populacional semelhante.

## Principais achados

- A área urbana de SJRP passou de ~4.100 ha (1985) para ~12.000 ha (2025).
- 82% de toda a expansão urbana entre 1985–2025 converteu pastagem.
- Essa dependência de pastagem caiu ao longo do tempo: 84% (1985-95) → 78% (1995-2005)
  → 77% (2005-15) → 56% (2015-25), enquanto "Mosaico de Usos" ganhou espaço como origem.

![Crescimento comparado](outputs/figuras/urban_growth_comparison.png)
![Origem da expansão por década](outputs/figuras/share_pastagem_by_period.png)

## Como rodar

Ver `docs/specs/2026-08-15-uso-cobertura-solo-rio-preto-design.md` para a
arquitetura, e `docs/plans/2026-08-15-uso-cobertura-solo-rio-preto-plan.md`
para os passos completos de ingestão e modelagem.

Fontes de dados brutos (não incluídas no repositório — baixe e coloque em `dados brutos/`):
- MapBiomas Coleção 11, Cobertura: https://brasil.mapbiomas.org/downloads/estatisticas/
- MapBiomas Transições: https://plataforma.brasil.mapbiomas.org (módulo Transições)
- População municipal: https://ftp.ibge.gov.br/Estimativas_de_Populacao/

## Stack

Python (pandas, psycopg2) + PostgreSQL + matplotlib.
```

- [ ] **Passo 2: Escrever `README.en.md`**

Tradução do mesmo conteúdo para inglês.

- [ ] **Passo 3: Commit**

```bash
git add README.md README.en.md
git commit -m "docs: README bilíngue com achados e instruções"
```
