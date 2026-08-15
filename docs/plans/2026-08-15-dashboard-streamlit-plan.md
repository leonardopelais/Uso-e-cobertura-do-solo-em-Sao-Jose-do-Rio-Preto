# Dashboard Streamlit (Fase 2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar um painel Streamlit interativo, lendo de um banco Neon (Postgres na nuvem), com as 8 perguntas do projeto original organizadas em 3 abas.

**Architecture:** Reexecuta o pipeline já existente apontado para o Neon (zero código novo de ingestão); um app Streamlit novo (`dashboard/`) lê as views via uma conexão própria (`st.secrets`); publicado no Streamlit Community Cloud.

**Tech Stack:** Streamlit, psycopg2, pandas, PostgreSQL (Neon).

**Spec:** `docs/specs/2026-08-15-dashboard-streamlit-design.md`

## Global Constraints

- Nenhum código novo de ingestão — o pipeline existente (`src/ingest_*.py`, `sql/01-04`) roda de novo, só apontado pro Neon.
- Segredos (connection string do Neon) nunca vão pro Git — usar `.streamlit/secrets.toml` (local) e o mecanismo de secrets do Streamlit Cloud (produção).
- Conexão do dashboard é separada da conexão do pipeline (`dashboard/db.py` novo, não reaproveita `src/db.py`).
- Filtro de cidade na barra lateral afeta só as perguntas comparativas (views 2, 5, 6); as views 1, 3, 4, 7, 8 ficam fixas em SJRP.

---

### Task 1: Criar conta e banco no Neon

**Files:** nenhum arquivo de código — conta e configuração externa.

- [ ] **Passo 1: Criar a conta**

Acesse https://neon.tech e crie uma conta — o jeito mais rápido é entrar com "Sign in with GitHub" (não precisa cartão de crédito).

- [ ] **Passo 2: Criar o projeto/banco**

Na tela inicial, crie um novo projeto (ex.: nome `riopreto`). O Neon já cria um banco padrão dentro dele.

- [ ] **Passo 3: Pegar a connection string**

No painel do projeto, procure "Connection string" (ou "Connection Details"). Copie a string
completa — tem o formato `postgresql://usuario:senha@ep-xxxxx.neon.tech/nomedobanco?sslmode=require`.

- [ ] **Passo 4: Guardar a connection string num arquivo local (não me diga a senha)**

Crie o arquivo `src/neon_config.py`:

```python
DATABASE_URL = "TROQUE_AQUI_PELA_CONNECTION_STRING_COMPLETA"
```

Cole a connection string do Passo 3 no lugar de `TROQUE_AQUI...`. Esse arquivo não vai pro
Git (mesma lógica do `db_config.py`).

- [ ] **Passo 5: Adicionar ao `.gitignore`**

```
src/neon_config.py
```

---

### Task 2: Adaptar `db.py` para apontar pro Neon quando necessário

**Files:**
- Modify: `src/db.py`

**Interfaces:**
- Consumes: `src/neon_config.py` (Task 1) — só quando a variável de ambiente `USE_NEON` estiver setada.
- Produces: `db.get_connection()` continua com a mesma assinatura; comportamento padrão (sem `USE_NEON`) não muda.

- [ ] **Passo 1: Editar `src/db.py`**

```python
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
```

- [ ] **Passo 2: Verificar que o comportamento padrão (local) continua igual**

```bash
cd "projeto uso e cobertura do solo - riopreto"
python -m pytest tests/test_data_quality.py -v
```

Esperado: PASS (mesmo resultado de antes — sem `USE_NEON`, conecta local como sempre).

- [ ] **Passo 3: Verificar a conexão com o Neon**

```bash
cd src
USE_NEON=1 python -c "from db import get_connection; c = get_connection(); print('conexão Neon ok'); c.close()"
```

Esperado: `conexão Neon ok`.

- [ ] **Passo 4: Commit**

```bash
git add src/db.py .gitignore
git commit -m "feat: db.py conecta no Neon quando USE_NEON está setado"
```

---

### Task 3: Migrar os dados para o Neon

**Files:** nenhum arquivo novo — reexecução dos scripts existentes.

**Interfaces:**
- Consumes: `sql/01_schema.sql`, `sql/02_dimensions.sql`, `sql/03_facts.sql`, `sql/04_views_analise.sql`, `src/ingest_population.py`, `src/ingest_coverage.py`, `src/ingest_transition.py`, `src/neon_config.py` (Task 1), `USE_NEON` (Task 2).

- [ ] **Passo 1: Rodar o schema no Neon**

```bash
cd "projeto uso e cobertura do solo - riopreto"
NEON_URL=$(python -c "import sys; sys.path.insert(0,'src'); from neon_config import DATABASE_URL; print(DATABASE_URL)")
psql "$NEON_URL" -f sql/01_schema.sql
```

Esperado: `CREATE TABLE` × 7.

- [ ] **Passo 2: Rodar as 3 ingestões Python apontadas pro Neon**

```bash
cd src
USE_NEON=1 python ingest_population.py
USE_NEON=1 python ingest_coverage.py
USE_NEON=1 python ingest_transition.py
cd ..
```

Esperado: as mesmas mensagens de linhas carregadas que já vimos localmente (645 municípios,
3.936 linhas de coverage, TRANSITION das 6 cidades).

- [ ] **Passo 3: Rodar dimensões, fatos e views no Neon**

```bash
psql "$NEON_URL" -f sql/02_dimensions.sql
psql "$NEON_URL" -f sql/03_facts.sql
psql "$NEON_URL" -f sql/04_views_analise.sql
```

- [ ] **Passo 4: Commit**

Nada para commitar nesta task — é só execução, sem arquivo novo.

---

### Task 4: Validar a migração

**Files:** nenhum arquivo novo — reexecução dos testes existentes.

**Interfaces:**
- Consumes: `tests/test_data_quality.py`, `USE_NEON` (Task 2).

- [ ] **Passo 1: Rodar os testes de qualidade apontados pro Neon**

```bash
cd "projeto uso e cobertura do solo - riopreto"
USE_NEON=1 python -m pytest tests/test_data_quality.py -v
```

Esperado: PASS nos 2 testes (nenhuma linha órfã; soma de área de SJRP 2015-2025 entre
42.000 e 44.000 ha) — os mesmos resultados de quando rodamos local, confirmando que a
migração está correta.

---

### Task 5: Esqueleto do dashboard

**Files:**
- Create: `dashboard/db.py`
- Create: `dashboard/app.py` (versão mínima, 1 gráfico)
- Create: `.streamlit/secrets.toml`
- Modify: `requirements.txt`
- Modify: `.gitignore`

**Interfaces:**
- Produces: `db.get_connection() -> psycopg2.connection` (usado pelo resto do `app.py` na Task 6).

- [ ] **Passo 1: Criar `dashboard/db.py`**

```python
import psycopg2
import streamlit as st


def get_connection():
    return psycopg2.connect(st.secrets["DATABASE_URL"])
```

- [ ] **Passo 2: Criar `.streamlit/secrets.toml`**

```toml
DATABASE_URL = "TROQUE_AQUI_PELA_MESMA_CONNECTION_STRING_DO_NEON_CONFIG"
```

Cole a mesma connection string que está em `src/neon_config.py`.

- [ ] **Passo 3: Adicionar ao `.gitignore`**

```
.streamlit/secrets.toml
```

- [ ] **Passo 4: Adicionar `streamlit` ao `requirements.txt`**

Acrescente uma linha `streamlit` ao arquivo já existente.

```bash
pip install streamlit
```

- [ ] **Passo 5: Criar `dashboard/app.py` (versão mínima)**

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import pandas as pd
import streamlit as st
from db import get_connection


@st.cache_data
def run_query(sql):
    conn = get_connection()
    df = pd.read_sql(sql, conn)
    conn.close()
    return df


st.set_page_config(page_title="Uso do Solo em Rio Preto", layout="wide")
st.title("Uso e Cobertura do Solo em São José do Rio Preto (1985-2025)")

df1 = run_query("SELECT * FROM vw_urban_growth_sjrp")
st.subheader("Evolução da área urbana de SJRP")
st.line_chart(df1, x="year", y="area_ha")
```

- [ ] **Passo 6: Rodar localmente e verificar no navegador**

```bash
cd "projeto uso e cobertura do solo - riopreto"
streamlit run dashboard/app.py
```

Abra o link que aparece no terminal (geralmente `http://localhost:8501`) e confira que o
gráfico de evolução da área urbana aparece.

- [ ] **Passo 7: Commit**

```bash
git add dashboard/db.py dashboard/app.py requirements.txt .gitignore
git commit -m "feat: esqueleto do dashboard Streamlit (1 gráfico funcionando)"
```

---

### Task 6: Completar as 3 abas

**Files:**
- Modify: `dashboard/app.py`

**Interfaces:**
- Consumes: as 8 views (`vw_urban_growth_sjrp`, `vw_urban_growth_comparison`,
  `vw_transition_to_urban_sjrp`, `vw_share_pastagem_by_period`, `vw_share_pastagem_by_city`,
  `vw_ranking_pastagem_to_urban`, `vw_agri_composition_over_time`,
  `vw_agri_transitions_by_period`), `dim_municipality` (para a lista de cidades do filtro).

- [ ] **Passo 1: Reescrever `dashboard/app.py` completo**

```python
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent))

import pandas as pd
import streamlit as st
from db import get_connection


@st.cache_data
def run_query(sql):
    conn = get_connection()
    df = pd.read_sql(sql, conn)
    conn.close()
    return df


st.set_page_config(page_title="Uso do Solo em Rio Preto", layout="wide")
st.title("Uso e Cobertura do Solo em São José do Rio Preto (1985-2025)")

cities_df = run_query(
    "SELECT municipality FROM dim_municipality WHERE is_comparison_group ORDER BY municipality"
)
all_cities = cities_df["municipality"].tolist()
selected_cities = st.sidebar.multiselect(
    "Cidades (perguntas comparativas)", all_cities, default=all_cities
)

tab1, tab2, tab3 = st.tabs(["Crescimento urbano", "Origem da expansão", "Composição agrícola"])

with tab1:
    st.subheader("Evolução da área urbana de SJRP")
    df1 = run_query("SELECT * FROM vw_urban_growth_sjrp")
    st.line_chart(df1, x="year", y="area_ha")

    st.subheader("Crescimento comparado (%)")
    df2 = run_query("SELECT * FROM vw_urban_growth_comparison")
    df2 = df2[df2["municipality"].isin(selected_cities)]
    st.line_chart(df2.pivot(index="year", columns="municipality", values="growth_pct"))

with tab2:
    st.subheader("O que virou área urbana em SJRP, por década")
    df3 = run_query("SELECT * FROM vw_transition_to_urban_sjrp")
    period3 = st.selectbox("Período", sorted(df3["period"].unique()), key="period3")
    st.bar_chart(df3[df3["period"] == period3].set_index("origin_class")["area_ha"])

    st.subheader("% da área urbana nova vinda de pastagem, por período (SJRP)")
    df4 = run_query("SELECT * FROM vw_share_pastagem_by_period")
    st.bar_chart(df4.sort_values("period").set_index("period")["pastagem_pct"])

    st.subheader("Mesmo padrão, nas cidades do grupo")
    df5 = run_query("SELECT * FROM vw_share_pastagem_by_city")
    df5 = df5[df5["municipality"].isin(selected_cities)]
    st.bar_chart(df5.pivot_table(index="period", columns="municipality", values="pastagem_pct"))

    st.subheader("Ranking: quem converteu mais pastagem em área urbana")
    df6 = run_query("SELECT * FROM vw_ranking_pastagem_to_urban ORDER BY rank_absoluto")
    df6 = df6[df6["municipality"].isin(selected_cities)]
    st.dataframe(df6, hide_index=True)

with tab3:
    st.subheader("Composição agrícola de SJRP ao longo do tempo")
    df7 = run_query("SELECT * FROM vw_agri_composition_over_time")
    st.line_chart(df7.pivot(index="year", columns="class_name", values="area_ha"))

    st.subheader("Transições entre classes agrícolas, por período")
    df8 = run_query("SELECT * FROM vw_agri_transitions_by_period")
    period8 = st.selectbox("Período", sorted(df8["period"].unique()), key="period8")
    st.dataframe(df8[df8["period"] == period8], hide_index=True)
```

- [ ] **Passo 2: Rodar localmente**

```bash
streamlit run dashboard/app.py
```

- [ ] **Passo 3: Verificar no navegador**

Confira as 3 abas: os gráficos aparecem, o filtro de cidade na barra lateral muda os
gráficos comparativos (aba 1: segundo gráfico; aba 2: terceiro gráfico e o ranking), e os
seletores de período funcionam nas abas 2 e 3.

- [ ] **Passo 4: Commit**

```bash
git add dashboard/app.py
git commit -m "feat: completa as 3 abas do dashboard (8 perguntas)"
```

---

### Task 7: Publicar no Streamlit Community Cloud

**Files:** nenhum arquivo de código — publicação e configuração externa.

- [ ] **Passo 1: Enviar o código pro GitHub**

Se o repositório ainda não estiver no GitHub, esse é o momento — sem isso o Streamlit Cloud
não tem de onde publicar.

- [ ] **Passo 2: Criar conta no Streamlit Community Cloud**

Acesse https://share.streamlit.io e entre com "Sign in with GitHub".

- [ ] **Passo 3: Criar o app**

Clique em "New app", selecione o repositório, e aponte o caminho principal para
`dashboard/app.py`.

- [ ] **Passo 4: Configurar os secrets**

Na tela de configuração do app (ou em "Settings → Secrets" depois de criado), cole:

```toml
DATABASE_URL = "sua_connection_string_do_neon"
```

- [ ] **Passo 5: Publicar e testar**

Clique em "Deploy". Depois que o app subir, abra o link público e confira as 3 abas de
novo, agora publicadas.

---

### Task 8: Atualizar o README com o link publicado

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`

- [ ] **Passo 1: Adicionar o link do dashboard nos dois READMEs**

Logo após a introdução, adicione uma linha com o link público do Streamlit (ex.:
`**Dashboard interativo:** https://seuprojetoriopreto.streamlit.app`), em português no
`README.md` e em inglês no `README.en.md`.

- [ ] **Passo 2: Commit**

```bash
git add README.md README.en.md
git commit -m "docs: adiciona link do dashboard publicado"
```
