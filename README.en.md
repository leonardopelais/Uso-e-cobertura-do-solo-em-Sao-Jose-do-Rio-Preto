# Land Use and Land Cover in São José do Rio Preto, Brazil (1985–2025)

This is a portfolio project I built to learn databases hands-on, using a topic I was
genuinely curious about: how the city of São José do Rio Preto, in inland São Paulo state,
Brazil, has physically grown over the last 40 years, and what land it grew over. I also
compare that growth against 5 other São Paulo cities of similar population size (Mogi das
Cruzes, Jundiaí, Piracicaba, Santos, and Mauá), so I'd have something to measure it against
instead of just looking at one isolated number.

The data comes from [MapBiomas](https://brasil.mapbiomas.org/) (satellite-based land use
and land cover mapping, collection 11) and from Brazil's census bureau, IBGE. The pipeline
is Python for ingestion, PostgreSQL for modeling and analysis, and Python again for the
charts.

## What I found

SJRP's urban area went from roughly 4,100 hectares in 1985 to about 12,000 hectares in
2025 — nearly tripling. The more interesting part is what that area replaced: 82% of all
urban expansion in that period came from land that used to be pasture.

That number isn't constant, though. Broken down by decade, reliance on pasture has been
dropping: 84% between 1985 and 1995, 78% between 1995 and 2005, 77% between 2005 and 2015,
and only 56% between 2015 and 2025. In its place, "Mixed-Use Mosaic" (mixed agricultural
land) has been picking up as a source of expansion over the last couple of decades.

Comparing against the other cities in the group, SJRP converted the most pasture into urban
land in absolute terms (5,818 ha). On the other end, Santos barely did any of that (1.5 ha)
— which makes sense, it's a coastal city that never had much pasture to begin with. In
terms of relative growth rate, Piracicaba and SJRP lead the group (around 190% since 1985),
while Santos and Mauá grew much less (between 20% and 33%).

![Comparative growth](outputs/figuras/urban_growth_comparison.png)
![Source of expansion by decade](outputs/figuras/share_pastagem_by_period.png)

## Architecture

The pipeline is hybrid: Python reads the raw files and loads them into PostgreSQL without
touching the data itself; from there on it's all SQL — modeling into dimensions and facts,
and the analysis questions become views (using JOINs, GROUP BY, window functions, RANK()).
At the end, Python reads those views and draws the charts.

I documented the decision process and the implementation in more detail here, in case
anyone wants to understand why I made each choice (both in Portuguese):
- [Design spec](docs/superpowers/specs/2026-08-15-uso-cobertura-solo-rio-preto-design.md)
- [Implementation plan](docs/superpowers/plans/2026-08-15-uso-cobertura-solo-rio-preto-plan.md)

## How to run it

1. Install PostgreSQL and create a database called `riopreto`
2. `pip install -r requirements.txt`
3. Download the raw data (sources below) into a `dados brutos/` folder
4. Create a `src/db_config.py` file with `PASSWORD = "your_password"` — this file is
   gitignored on purpose, so everyone uses their own local password
5. Run, in this order: `sql/01_schema.sql`, the three ingestion scripts
   (`src/ingest_population.py`, `src/ingest_coverage.py`, `src/ingest_transition.py`),
   `sql/02_dimensions.sql`, `sql/03_facts.sql`, and `sql/04_views_analise.sql`
6. `python src/charts.py`

To run the tests: `pytest tests/`

## Where the data comes from

I didn't upload the raw files to the repo — the main one alone is over 75 MB, and GitHub
won't take it.

- **MapBiomas, Collection 11, Coverage**: https://brasil.mapbiomas.org/downloads/estatisticas/
- **MapBiomas, Transitions**: there's no ready-made spreadsheet for this collection yet, so
  I used the interactive platform instead (https://plataforma.brasil.mapbiomas.org) —
  Coverage → Transitions module, selecting the territory, the period, and checking all
  legend levels
- **Municipal population**: https://ftp.ibge.gov.br/Estimativas_de_Populacao/

## Stack

Python (pandas, psycopg2, matplotlib), PostgreSQL, pytest.
