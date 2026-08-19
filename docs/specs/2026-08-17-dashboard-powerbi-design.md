# Design — Dashboard Power BI (Sub-projeto)

**Data:** 2026-08-17
**Status:** aprovado, aguardando revisão final do Leonardo antes do plano de implementação.

---

## 1. Objetivo

Sub-projeto complementar ao dashboard Streamlit já publicado: um relatório no **Power BI**,
replicando as mesmas 8 perguntas do projeto original. Motivação de portfólio: Power BI é a
ferramenta mais pedida em vaga de análise de dados no Brasil — diferente do Tableau (que
funciona melhor como peça única), o Power BI é feito pra relatórios com múltiplas páginas e
filtros, então reaproveitar as 8 perguntas já validadas mostra domínio real da ferramenta
em cima de uma análise que já se provou correta.

## 2. Decisões

| Tema | Decisão |
|---|---|
| Escopo do conteúdo | As mesmas 8 perguntas do Streamlit, em 3 páginas |
| Fonte de dados | Conexão direta do Power BI Desktop no banco Neon (mesmo já usado pelos outros sub-projetos) |
| Publicação | **"Publicar na Web"** — link público interativo, mesmo com conta pessoal |
| Arquivo `.pbix` | Não entra no repositório |

### Racional não óbvio

- **"Publicar na Web" funciona com conta pessoal — descoberta feita durante o brainstorm.**
  A suposição inicial (herdada da limitação real do Power BI Service tradicional) era que
  só dava pra publicar com conta corporativa. Um exemplo real visto no LinkedIn mostrou que
  o recurso "Publicar na Web" gera um link público (`app.powerbi.com/view?r=...`) mesmo com
  conta pessoal Microsoft. A contrapartida: esse recurso deixa o relatório **e os dados por
  trás dele 100% públicos, sem nenhuma restrição de acesso**. Isso é aceitável aqui porque
  os dados do projeto (MapBiomas, IBGE) já são públicos — não há nada sensível exposto.
- **Por que replicar as 8 perguntas, e não uma peça focada (diferente do Tableau):** o
  Power BI é estruturalmente uma ferramenta de relatório com páginas e filtros — usá-la pra
  uma peça única desperdiçaria o que ela faz de melhor. Reaproveitar as 8 perguntas já
  validadas também evita reabrir decisões analíticas — o foco aqui é demonstrar a
  ferramenta, não a análise.
- **Por que incluir medidas DAX mesmo já tendo os cálculos prontos em SQL:** as views já
  calculam tudo que os gráficos precisam, então tecnicamente nada obriga usar DAX. Mas DAX
  é a competência mais associada ao Power BI especificamente — pelo menos 2-3 medidas
  (ranking, percentuais) demonstram essa parte da ferramenta, sem duplicar toda a lógica já
  validada em SQL.
- **Por que o `.pbix` não vai pro Git:** mesmo racional já usado no Tableau — binário sem
  diff útil, e risco de embutir a senha do Neon se salvo com "lembrar senha" marcado.

## 3. Conteúdo e estrutura

3 páginas, espelhando a mesma divisão temática já usada no Streamlit:

| Página | Perguntas (views) |
|---|---|
| Crescimento urbano | 1, 2 (`vw_urban_growth_sjrp`, `vw_urban_growth_comparison`) |
| Origem da expansão | 3, 4, 5, 6 (`vw_transition_to_urban_sjrp`, `vw_share_pastagem_by_period`, `vw_share_pastagem_by_city`, `vw_ranking_pastagem_to_urban`) |
| Composição agrícola | 7, 8 (`vw_agri_composition_over_time`, `vw_agri_transitions_by_period`) |

**Slicer de cidade**, presente nas 3 páginas, afetando só as perguntas comparativas (2, 5,
6) — mesmo comportamento já usado no Streamlit.

## 4. Dados e modelagem

- Power BI Desktop conecta direto no Neon, importando as 8 views já existentes — nenhuma
  view SQL nova.
- Relacionamentos entre as tabelas modelados dentro do próprio Power BI (modelo interno da
  ferramenta, independente do modelo dimensional já existente no Postgres).
- Pelo menos 2-3 **medidas DAX** (ex.: ranking via `RANKX()`, percentuais) — ver racional
  na Seção 2.

## 5. Publicação

- Instalar **Power BI Desktop** (gratuito)
- Conectar no Neon usando a mesma connection string já em uso (`src/neon_config.py`) —
  inserida diretamente no conector nativo de Postgres do Power BI, não em nenhum arquivo do
  repositório
- Publicar via **"Publicar na Web"**, gerando o link público
- Adicionar o link nos dois READMEs (`README.md` e `README.en.md`), mesmo padrão já usado
  para os links do Streamlit

## 6. Fases de execução

| Fase | O que é |
|---|---|
| 1. Instalar o Power BI Desktop | Manual, guiado |
| 2. Conectar no Neon e importar as 8 views | Conector nativo de Postgres |
| 3. Modelar os relacionamentos entre as tabelas | Modelo interno do Power BI |
| 4. Criar medidas DAX | Pelo menos 2-3 (ranking, percentuais) |
| 5. Montar as 3 páginas | Gráficos + slicer de cidade |
| 6. Publicar na Web | Gera o link público interativo |
| 7. Atualizar os READMEs | Adicionar o link publicado |

## 7. Fora de escopo

- Qualquer análise nova além das 8 perguntas já validadas.
- Versionar o arquivo `.pbix` no repositório (ver racional na Seção 2).
