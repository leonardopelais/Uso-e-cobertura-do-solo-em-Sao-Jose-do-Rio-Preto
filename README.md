# Uso e Cobertura do Solo em São José do Rio Preto (1985–2025)

Como a mancha urbana de São José do Rio Preto (SP) cresceu nos últimos 40 anos, o que ela
substituiu, e como isso se compara a 5 cidades paulistas de porte populacional semelhante
(Mogi das Cruzes, Jundiaí, Piracicaba, Santos e Mauá).

Projeto de portfólio construído com Python + SQL (PostgreSQL) sobre dados do
[MapBiomas](https://brasil.mapbiomas.org/) (Coleção 11) e do IBGE.

## Principais achados

- A área urbana de SJRP passou de **~4.100 ha (1985)** para **~12.000 ha (2025)** — quase
  triplicou.
- **82% de toda a expansão urbana** de SJRP entre 1985–2025 converteu área que antes era
  **pastagem**.
- Essa dependência de pastagem **caiu ao longo do tempo**: 84% (1985-95) → 78% (1995-2005)
  → 77% (2005-15) → **56% (2015-25)** — "Mosaico de Usos" ganhou espaço como origem da
  expansão nas últimas décadas.
- Entre as 6 cidades comparadas, **SJRP foi quem mais converteu pastagem em área urbana em
  termos absolutos** (5.818 ha) — Santos, cidade litorânea com pouco pasto pra começo de
  conversa, converteu quase nada (1,5 ha).
- Piracicaba e SJRP tiveram o crescimento urbano relativo mais rápido do grupo (~190% desde
  1985); Santos e Mauá cresceram bem menos (~20-33%).

![Crescimento comparado](outputs/figuras/urban_growth_comparison.png)
![Origem da expansão por década](outputs/figuras/share_pastagem_by_period.png)

## Arquitetura

Pipeline híbrido: Python ingere os dados brutos → PostgreSQL modela (dimensões + fatos) e
responde as perguntas de análise via SQL (JOINs, `GROUP BY`, window functions, `RANK()`) →
Python gera os gráficos.

Detalhes completos:
- [Spec de design](docs/superpowers/specs/2026-08-15-uso-cobertura-solo-rio-preto-design.md)
- [Plano de implementação](docs/superpowers/plans/2026-08-15-uso-cobertura-solo-rio-preto-plan.md)

## Como rodar

1. Instale PostgreSQL e crie um banco `riopreto`
2. `pip install -r requirements.txt`
3. Baixe os dados brutos (ver "Fontes de dados" abaixo) e coloque em `dados brutos/`
4. Crie `src/db_config.py` com `PASSWORD = "sua_senha"` (esse arquivo não vai pro Git)
5. Rode os scripts SQL em ordem: `sql/01_schema.sql`, ingestões Python
   (`src/ingest_population.py`, `src/ingest_coverage.py`, `src/ingest_transition.py`),
   `sql/02_dimensions.sql`, `sql/03_facts.sql`, `sql/04_views_analise.sql`
6. `python src/charts.py`

Testes: `pytest tests/`

## Fontes de dados brutos

Não incluídas no repositório (75 MB+; GitHub rejeita arquivos grandes).

- **MapBiomas Coleção 11, Cobertura**:
  https://brasil.mapbiomas.org/downloads/estatisticas/
- **MapBiomas Transições** (módulo interativo, sem download pronto para a Coleção 11):
  https://plataforma.brasil.mapbiomas.org — Cobertura → Transições, selecionar o
  território e o período, marcar todos os níveis de legenda
- **População municipal**: https://ftp.ibge.gov.br/Estimativas_de_Populacao/

## Stack

Python (pandas, psycopg2, matplotlib) + PostgreSQL + pytest.
