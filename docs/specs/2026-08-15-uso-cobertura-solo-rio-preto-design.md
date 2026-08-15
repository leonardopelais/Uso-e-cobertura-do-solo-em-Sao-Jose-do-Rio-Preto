# Design — Uso e Cobertura do Solo em São José do Rio Preto

**Data:** 2026-08-15
**Status:** aprovado, aguardando revisão final do Leonardo antes do plano de implementação.

---

## 1. Objetivo

Projeto de **portfólio** para o Leonardo entrar na área de análise de dados, com dois
objetivos que valem igual:

1. Produzir uma análise pública e bem contada sobre expansão urbana (o portfólio em si).
2. **Aprender banco de dados na prática** — este é o eixo de aprendizado do projeto.

**Pergunta central:** como a mancha urbana de São José do Rio Preto (SP) cresceu entre
1985 e 2025, o que ela substituiu, e como isso se compara a cidades paulistas de porte
populacional semelhante. Complementarmente: como a composição agrícola da região mudou
no mesmo período (ângulo econômico).

## 2. Decisões de escopo

| Tema | Decisão |
|---|---|
| Grupo de comparação | 5 cidades de população mais próxima de SJRP: Mogi das Cruzes, Jundiaí, Piracicaba, Santos, Mauá |
| Banco de dados | PostgreSQL local |
| Arquitetura | Híbrida: Python ingere → SQL modela e analisa → Python visualiza |
| Entregável fase 1 | Repositório GitHub (README bilíngue + SQL + notebook + gráficos) |
| Entregável fase 2 | Dashboard interativo — ferramenta a definir depois |
| Fontes de dados | MapBiomas COVERAGE, MapBiomas TRANSITION (via Plataforma interativa), população IBGE |
| Idioma | Textos/análise em PT; código, tabelas e colunas em EN; README bilíngue |
| Dinâmica de trabalho | Claude escreve e explica cada passo; Leonardo revisa e roda |

### Racional de decisões não óbvias

- **Comparação por porte populacional** (não por vizinhança geográfica) exige um JOIN real
  entre MapBiomas e IBGE pela chave `geocode` — testado e confirmado (`35` + `49805` =
  `3549805` para SJRP, bate nos dois arquivos).
- **TRANSITION é obrigatório, não opcional.** COVERAGE só mostra o estoque de área por
  classe e ano; sozinho, não permite afirmar que a cidade cresceu *sobre* pastagem — seria
  extrapolação. Só o TRANSITION mede pares origem→destino de fato.
- **Grupo de comparação reduzido de 11 para 5 cidades.** ±30% da população de SJRP (504.166
  hab.) resultava em 11 municípios — mas o TRANSITION exige exportação manual (sem API),
  4 períodos por cidade. Com 11 cidades seriam 44 exports; reduzido para as 5 de população
  mais próxima (todas a menos de 76 mil hab. de distância — há um salto perceptível de
  população depois delas), ficando em 20 exports. Mesmo grupo usado tanto na comparação
  de ritmo de crescimento (que usaria COVERAGE de graça para as 11) quanto na análise
  detalhada, por simplicidade.
- **PIB municipal do IBGE descartado** como fonte adicional: a série
  (`ftp.ibge.gov.br/Pib_Municipios/`) só cobre 2010-2023, não bate com o período do projeto
  (1985-2025). O ângulo econômico foi replanejado para usar dados que já temos (composição
  agrícola por classe, via MapBiomas) — ver Seção 5.
- **Power BI adiado** para fase 2: publicar painel público exige conta corporativa; com
  Gmail pessoal o painel não teria link clicável.
- **Dados brutos ficam fora do Git** (arquivo principal tem 75 MB+; GitHub rejeita >100 MB).
  O README documenta onde baixar e o script de ingestão cuida do resto.

## 3. Arquitetura e fluxo de dados

```
FONTES EXTERNAS
  ├── MapBiomas COVERAGE .xlsx        (obtido)
  ├── MapBiomas TRANSITION (Plataforma, exports manuais por cidade/período)
  └── População municipal IBGE .xls   (obtido)
            │
            ▼
  [1] INGESTÃO — Python
      lê os arquivos, converte formato largo→longo, grava sem alterar regras de negócio
            │
            ▼
  ┌─────────────── PostgreSQL ───────────────┐
  │  [2] CAMADA STAGING (espelho do bruto)    │
  │      staging_coverage / staging_transition │
  │      staging_population                    │
  │            │                              │
  │            ▼  scripts .sql numerados      │
  │  [3] CAMADA ANALÍTICA (modelo dimensional)│
  │      dim_municipality / dim_class          │
  │      fact_coverage / fact_transition       │
  │            │                              │
  │            ▼                              │
  │  [4] CAMADA DE CONSULTAS (views)          │
  │      uma view por pergunta da análise     │
  └───────────────────┬───────────────────────┘
                      ▼
  [5] APRESENTAÇÃO — Python
      lê as views → gera gráficos → README
```

**Princípio-guia:** a camada *staging* nunca é alterada — é o espelho fiel do dado bruto.
Toda decisão de negócio (agrupamento, filtros, nomes) mora na camada analítica ou nas views,
nunca no staging. Isso torna qualquer número do README rastreável até sua origem.

### Estrutura de pastas

```
projeto uso e cobertura do solo - riopreto/
├── README.md / README.en.md
├── dados brutos/          (fora do Git)
├── src/                   ingest_*.py, charts.py
├── sql/                   01_schema, 02_dimensions, 03_facts, 04_views_analise
├── outputs/figuras/
└── docs/
```

Arquivos SQL são numerados: a ordem de execução importa (dimensões antes dos fatos).

## 4. Modelo de dados

Modelo dimensional (fato + dimensões): dimensões guardam "quem/o quê" uma vez só; fatos
guardam "quanto" e referenciam as dimensões via chave estrangeira.

**`dim_municipality`**
| coluna | tipo | observação |
|---|---|---|
| `geocode` | INTEGER, PK | código IBGE, ex. `3549805` p/ SJRP |
| `municipality` | TEXT | nome |
| `state` | TEXT | UF |
| `population` | INTEGER | IBGE, ano-base 2025 |
| `is_comparison_group` | BOOLEAN | `true` para SJRP + as 5 cidades do grupo |

**`dim_class`**
| coluna | tipo | observação |
|---|---|---|
| `class_id` | INTEGER, PK | código MapBiomas |
| `class_level_0` … `class_level_4` | TEXT | hierarquia completa |

**`fact_coverage`** — uma medição (município, classe, ano)
| coluna | tipo |
|---|---|
| `geocode` | INTEGER, FK → dim_municipality |
| `class_id` | INTEGER, FK → dim_class |
| `year` | INTEGER (1985–2025) |
| `area_ha` | NUMERIC |

**`fact_transition`** — uma medição (município, origem→destino, período)
| coluna | tipo |
|---|---|
| `geocode` | INTEGER, FK → dim_municipality |
| `class_id_from` | INTEGER, FK → dim_class |
| `class_id_to` | INTEGER, FK → dim_class |
| `period` | TEXT, ex. `"1985-1995"` |
| `area_ha` | NUMERIC |

Sem `dim_year` — ano não tem atributos próprios além do número; criar uma tabela só para
isso seria complexidade sem ganho (YAGNI consciente).

### Grupo de comparação (dado real, testado)

| Cidade | População (2025) | Diferença p/ SJRP |
|---|---:|---:|
| São José do Rio Preto | 504.166 | — |
| Mogi das Cruzes | 470.302 | 33.864 |
| Jundiaí | 463.039 | 41.127 |
| Piracicaba | 440.835 | 63.331 |
| Santos | 429.547 | 74.619 |
| Mauá | 429.014 | 75.152 |

### Nível de classe usado no TRANSITION

Exports feitos com **todos os 4 níveis marcados simultaneamente** — a Plataforma mostra
cada classe no seu nível mais detalhado disponível (ex.: "Área Urbanizada" e "Pastagem" no
nível 2, por não se subdividirem; "Soja"/"Café"/"Citrus" no nível 3). Padrão a repetir nos
exports das 5 cidades do grupo.

## 5. Perguntas da análise (views)

| # | Pergunta | View | Conceito de SQL praticado | Fonte |
|---|---|---|---|---|
| 1 | Como a área urbana de SJRP evoluiu ano a ano, 1985–2025? | `vw_urban_growth_sjrp` | filtro + JOIN simples | COVERAGE |
| 2 | Como o ritmo de crescimento de SJRP se compara às 5 cidades do grupo? | `vw_urban_growth_comparison` | JOIN + variação % | COVERAGE |
| 3 | O que virou área urbana em SJRP, por década? | `vw_transition_to_urban_sjrp` | `GROUP BY` + `SUM` | TRANSITION |
| 4 | Que % da área urbana nova veio de pastagem, e como isso mudou com o tempo? | `vw_share_pastagem_by_period` | window function (`SUM() OVER PARTITION BY`) | TRANSITION |
| 5 | Esse padrão se repete nas outras 5 cidades? | `vw_share_pastagem_by_city` | mesmo padrão de #4 + dimensão cidade | TRANSITION |
| 6 | Ranking: qual cidade converteu mais pastagem em área urbana? | `vw_ranking_pastagem_to_urban` | `RANK()` | TRANSITION |
| 7 | Como a área de cada cultura agrícola (cana, soja, café, citrus, pastagem) mudou ao longo dos 41 anos? | `vw_agri_composition_over_time` | `GROUP BY` classe + ano | COVERAGE |
| 8 | Quais culturas ganharam área às custas de quais outras (não só a conversão para urbano)? | `vw_agri_transitions_by_period` | mesma lógica de `fact_transition`, focando pares agrícolas | TRANSITION |

Nenhuma pergunta nova exige tabela nova — as classes agrícolas já existem em `dim_class`.

**Achado preliminar já confirmado nos dados piloto (SJRP):** a dependência de pastagem
como origem da área urbana nova caiu ao longo do tempo — 84% (1985-95) → 78% (1995-2005)
→ 77% (2005-15) → 56% (2015-25) — enquanto "Mosaico de Usos" cresceu de origem (14%→40%).
No mesmo piloto, a maior transição agrícola isolada foi Pastagem→Cana em 2005-2015
(3.953,89 ha), coerente com o boom do setor sucroalcooleiro no interior paulista nos anos
2000 — evidência a explorar na pergunta 8.

## 6. Validação e tratamento de erros

Baseado em dois erros reais já ocorridos durante a coleta (território errado — região
metropolitana em vez do município isolado — e nível de classe errado — nível 1 genérico
sem "Área Urbanizada" isolada).

**Camada 1 — ingestão (Python → staging):**
- Contagem de linhas esperada (COVERAGE = 77.406); o script recusa a carga se destoar.
- Validação de encoding (nomes acentuados conhecidos, ex. "São José do Rio Preto", devem
  aparecer corretos após a leitura).

**Camada 2 — staging → modelo dimensional:**
- Checagem de soma de área por município (o teste que revelou manualmente o erro de
  território no primeiro export de TRANSITION) — vira regra automática: soma de
  `fact_transition` por município-período comparada à área total esperada do município.
- JOIN sem perda: nenhuma linha de fato pode ficar sem município correspondente após o
  JOIN com `dim_municipality` pelo `geocode`.

**Camada 3 — views de análise:**
- Dado ainda não coletado (municípios/períodos de TRANSITION pendentes) não pode aparecer
  como zero num gráfico — a view sinaliza explicitamente a ausência (ex.: coluna
  `dado_disponivel`), evitando leitura enganosa.

**Camada 4 — constraints do banco:**
- `PRIMARY KEY` e `FOREIGN KEY` em todas as tabelas de fato/dimensão — o PostgreSQL recusa
  sozinho qualquer linha que aponte para um município ou classe inexistente.

## 7. Fases de execução

| Fase | O que é | Depende de |
|---|---|---|
| 0. Ambiente | Instalar PostgreSQL, libs Python (pandas, driver do banco, leitor de Excel), estrutura de pastas, Git | — |
| 1. Coleta manual restante | 4 exports de TRANSITION (décadas) × 5 cidades do grupo (SJRP já completo) | — (paralelo às demais fases) |
| 2. Ingestão | Scripts Python: staging + validações de linha/encoding | Fase 0; COVERAGE/população podem começar já, TRANSITION incrementalmente |
| 3. Modelagem | SQL: dimensões + fatos + validações de soma/integridade | Fase 2 |
| 4. Views de análise | As 8 consultas da Seção 5 | Fase 3 |
| 5. Visualização + README | Gráficos, README bilíngue, publicação no GitHub | Fase 4 |
| *6. Dashboard (fase 2 do projeto, fora de escopo agora)* | *Ferramenta a decidir depois* | *Fase 5* |

## 8. Dados já obtidos

- **MapBiomas COVERAGE** — `dados brutos/MAPBIOMAS_BRAZIL-COL.11-BIOME_STATE_MUNICIPALITY.xlsx`
  (75 MB). Aba `COVERAGE_11`, 77.406 linhas × 55 colunas (ID, geocode, município, classe em
  5 níveis, y1985…y2025). Formato largo, precisa virar longo na ingestão.
- **População IBGE** — `dados brutos/IBGE_POP2025_MUNICIPIOS.xls` (800 KB). 645 municípios
  de SP. `geocode` = COD.UF + COD.MUNIC, testado e compatível com o MapBiomas.
- **MapBiomas TRANSITION (piloto SJRP)** — 4 arquivos `Diagrama de Sankey {período}.csv`
  cobrindo 1985-1995, 1995-2005, 2005-2015, 2015-2025. Validados por soma cruzada (a
  trajetória de área urbana implícita bate com o total direto 1985→2025).

## 9. Pendências

- Replicar os 20 exports de TRANSITION (4 períodos × 5 cidades do grupo de comparação).
- Escolher a ferramenta do dashboard (fase 2).
- Confirmar se o Leonardo já tem conta no GitHub.
