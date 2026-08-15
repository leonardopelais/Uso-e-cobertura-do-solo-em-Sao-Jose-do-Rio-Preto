# Design — Dashboard Interativo (Fase 2)

**Data:** 2026-08-15
**Status:** aprovado, aguardando revisão final do Leonardo antes do plano de implementação.

---

## 1. Objetivo

Fase 2 do projeto de uso e cobertura do solo em São José do Rio Preto: transformar a
análise (hoje só gráficos estáticos em PNG) num **painel interativo publicado com link
público**, para que qualquer pessoa consiga abrir, filtrar e explorar os dados sem precisar
rodar nada localmente.

## 2. Decisões

| Tema | Decisão |
|---|---|
| Ferramenta | **Streamlit** — Python puro, publica de graça com link público |
| Escopo do Power BI | Adiado para um sub-projeto futuro, fora deste spec (mesmo grupo de comparação, mas entregável diferente — `.pbix` + prints, sem link público por conta da conta pessoal) |
| Banco de dados | **Neon** (PostgreSQL gratuito na nuvem) — banco local continua sendo o ambiente de desenvolvimento |
| Conteúdo | As 8 perguntas do projeto original, agrupadas em 3 abas temáticas |
| Filtro | Multiselect de cidade (afeta só as perguntas comparativas — 2, 5, 6) |
| Gráficos | Nativos do Streamlit (`st.line_chart`, `st.bar_chart`), não os PNGs estáticos existentes |

### Racional não óbvio

- **Reaproveitamento total do pipeline.** Nenhum código novo de ingestão é necessário — os
  mesmos scripts SQL e Python que populam o banco local populam o Neon, só trocando a
  connection string. Isso só é possível porque o pipeline original já foi desenhado em
  camadas (staging → dimensões/fatos → views) sem nada hardcoded pro ambiente local.
- **Dois bancos, dois propósitos.** O Postgres local continua como ambiente de
  desenvolvimento/teste; o Neon é especificamente a cópia que o painel público consulta. Não
  há sincronização automática entre os dois — os dados do projeto são históricos (imagens de
  satélite já processadas), não mudam com frequência, então popular o Neon uma vez é
  suficiente.
- **Conexão do dashboard é separada da conexão do pipeline** (`dashboard/db.py` novo, não
  reaproveita `src/db.py`). O motivo é o ambiente de execução: `src/db.py` lê a senha de um
  arquivo local (`db_config.py`) que só existe no notebook do Leonardo. O app publicado roda
  no servidor do Streamlit Cloud, que não tem acesso a esse arquivo — precisa buscar a senha
  via `st.secrets`, o mecanismo de segredos do próprio Streamlit.
- **Validação sem escrever testes novos.** Os testes de qualidade de dado que já existem
  (`tests/test_data_quality.py`) são reexecutados apontados pro Neon — se passarem, a
  migração está correta. Não há necessidade de duplicar lógica de validação.

## 3. Arquitetura e fluxo de dados

```
Neon (Postgres na nuvem, gratuito)
  ↑ populado rodando o MESMO pipeline que já existe
  │ (01_schema.sql → ingestões Python → 02_dimensions → 03_facts → 04_views)
  │ só trocando a connection string de "localhost" pra Neon
  │
Streamlit app (dashboard/app.py)
  │ lê as views via psycopg2/pandas — igual ao charts.py já faz,
  │ mas monta gráfico dinâmico em vez de salvar PNG fixo
  ▼
Streamlit Community Cloud (grátis)
  → conecta direto no GitHub, publica um link público
  → cada push atualiza o painel sozinho
```

Segredos (senha do banco) ficam em dois lugares, nenhum deles no código:
- Localmente: `.streamlit/secrets.toml` (fora do Git)
- No Streamlit Cloud: configurado na própria plataforma na hora de publicar

## 4. Estrutura de arquivos

```
projeto uso e cobertura do solo - riopreto/
├── dashboard/
│   ├── app.py          # página principal do Streamlit
│   └── db.py            # conexão via st.secrets
├── .streamlit/
│   └── secrets.toml      # gitignored — connection string do Neon
├── requirements.txt       # ganha uma linha: streamlit
└── src/                   # inalterado — pipeline continua igual
```

## 5. Conteúdo e filtros

3 abas, cada uma reunindo perguntas relacionadas:

| Aba | Perguntas (views) | O que mostra |
|---|---|---|
| Crescimento urbano | 1, 2 (`vw_urban_growth_sjrp`, `vw_urban_growth_comparison`) | Evolução da área urbana de SJRP e comparação com as 5 cidades |
| Origem da expansão | 3, 4, 5, 6 (`vw_transition_to_urban_sjrp`, `vw_share_pastagem_by_period`, `vw_share_pastagem_by_city`, `vw_ranking_pastagem_to_urban`) | O que virou cidade, queda da dependência de pastagem, mesmo padrão nas outras cidades, ranking |
| Composição agrícola | 7, 8 (`vw_agri_composition_over_time`, `vw_agri_transitions_by_period`) | Evolução de cana/soja/café/citrus/pastagem e trocas entre elas |

O filtro de cidade (multiselect na barra lateral, padrão: todas as 6 marcadas) afeta só as
perguntas comparativas (2, 5, 6). As perguntas especificamente sobre SJRP (1, 3, 4, 7, 8)
ficam fixas nela, já que é o assunto central do projeto.

## 6. Migração para o Neon e validação

Nenhum código novo — reexecução do que já existe, apontado pro banco novo:

1. Criar conta no Neon (grátis, sem cartão) e um banco lá
2. Rodar, na ordem, os mesmos arquivos: `01_schema.sql` → os 3 scripts Python de ingestão →
   `02_dimensions.sql` → `03_facts.sql` → `04_views_analise.sql`, com a connection string
   apontada pro Neon
3. Rodar `pytest tests/test_data_quality.py` de novo, apontado pro Neon, para confirmar que
   a migração bateu

## 7. Fases de execução

| Fase | O que é |
|---|---|
| 1. Banco na nuvem | Criar conta/projeto no Neon, guardar a connection string |
| 2. Migrar dados | Rodar o pipeline completo apontado pro Neon |
| 3. Validar migração | Rodar os testes de qualidade contra o Neon |
| 4. Esqueleto do app | Conexão + 1 aba funcionando localmente, testando contra o Neon |
| 5. Completar as 3 abas | Implementar as 8 perguntas nos gráficos interativos |
| 6. Testar localmente | Conferir os filtros e os 3 temas funcionando |
| 7. Publicar | Streamlit Community Cloud, conectar ao GitHub, configurar os secrets lá |
| 8. Atualizar README | Adicionar o link do painel publicado |

## 8. Fora de escopo

- Power BI (`.pbix` + prints) — sub-projeto futuro, próprio brainstorm quando chegar a vez.
- Sincronização automática entre o Postgres local e o Neon — os dados são históricos e não
  mudam com frequência; popular o Neon uma vez é suficiente para este escopo.
