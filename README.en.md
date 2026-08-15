# Land Use and Land Cover in São José do Rio Preto, Brazil (1985–2025)

How the urban footprint of São José do Rio Preto (SP, Brazil) grew over the last 40 years,
what land it replaced, and how it compares to 5 São Paulo state cities of similar
population size (Mogi das Cruzes, Jundiaí, Piracicaba, Santos, and Mauá).

Data portfolio project built with Python + SQL (PostgreSQL) on top of
[MapBiomas](https://brasil.mapbiomas.org/) (Collection 11) and Brazilian census bureau
(IBGE) data.

## Key findings

- SJRP's urban area grew from **~4,100 ha (1985)** to **~12,000 ha (2025)** — nearly
  tripling.
- **82% of all urban expansion** in SJRP between 1985–2025 converted land that was
  previously **pasture**.
- That reliance on pasture **declined over time**: 84% (1985-95) → 78% (1995-2005) → 77%
  (2005-15) → **56% (2015-25)** — "Mixed-Use Mosaic" grew as a source of expansion in the
  most recent decade.
- Among the 6 compared cities, **SJRP converted the most pasture into urban area in
  absolute terms** (5,818 ha) — Santos, a coastal city with little pasture to begin with,
  converted almost none (1.5 ha).
- Piracicaba and SJRP had the fastest relative urban growth in the group (~190% since
  1985); Santos and Mauá grew far less (~20-33%).

![Comparative growth](outputs/figuras/urban_growth_comparison.png)
![Source of expansion by decade](outputs/figuras/share_pastagem_by_period.png)

## Architecture

Hybrid pipeline: Python ingests the raw data → PostgreSQL models it (dimensions + facts)
and answers the analysis questions via SQL (JOINs, `GROUP BY`, window functions, `RANK()`)
→ Python generates the charts.

Full details:
- [Design spec](docs/superpowers/specs/2026-08-15-uso-cobertura-solo-rio-preto-design.md) (Portuguese)
- [Implementation plan](docs/superpowers/plans/2026-08-15-uso-cobertura-solo-rio-preto-plan.md) (Portuguese)

## How to run

1. Install PostgreSQL and create a `riopreto` database
2. `pip install -r requirements.txt`
3. Download the raw data (see "Data sources" below) into `dados brutos/`
4. Create `src/db_config.py` with `PASSWORD = "your_password"` (this file is gitignored)
5. Run the SQL scripts in order: `sql/01_schema.sql`, the Python ingestion scripts
   (`src/ingest_population.py`, `src/ingest_coverage.py`, `src/ingest_transition.py`),
   `sql/02_dimensions.sql`, `sql/03_facts.sql`, `sql/04_views_analise.sql`
6. `python src/charts.py`

Tests: `pytest tests/`

## Raw data sources

Not included in the repository (75 MB+; GitHub rejects large files).

- **MapBiomas Collection 11, Coverage**:
  https://brasil.mapbiomas.org/downloads/estatisticas/
- **MapBiomas Transitions** (interactive module, no ready-made download for Collection 11):
  https://plataforma.brasil.mapbiomas.org — Coverage → Transitions, select the territory
  and period, check all legend levels
- **Municipal population**: https://ftp.ibge.gov.br/Estimativas_de_Populacao/

## Stack

Python (pandas, psycopg2, matplotlib) + PostgreSQL + pytest.
