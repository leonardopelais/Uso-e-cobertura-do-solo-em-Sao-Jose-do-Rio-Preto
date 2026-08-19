# Dashboard Power BI (Sub-projeto) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Publicar um relatório Power BI com link público interativo ("Publicar na Web"), replicando as 8 perguntas do Streamlit em 3 páginas.

**Architecture:** Power BI Desktop conecta direto no Neon (mesmo banco dos outros sub-projetos), importa as 8 views + `dim_municipality`, modela relacionamentos pra o slicer de cidade funcionar entre páginas, e usa medidas DAX pra ranking e percentuais.

**Tech Stack:** Power BI Desktop (gratuito), conector nativo PostgreSQL, DAX.

**Spec:** `docs/specs/2026-08-17-dashboard-powerbi-design.md`

## Global Constraints

- Nenhuma view SQL nova — reaproveita as 8 views + `dim_municipality` já existentes.
- Arquivo `.pbix` nunca vai pro Git.
- Slicer de cidade afeta só as perguntas comparativas (2, 5, 6).
- Publicação via "Publicar na Web" (não Power BI Service tradicional).

Este plano é majoritariamente manual (Power BI Desktop é uma ferramenta visual, não um editor de código) — a maior parte das tasks é o Leonardo seguindo passos guiados e confirmando o que aparece na tela, exceto a Task 9 (README), que é código de verdade.

---

### Task 1: Instalar o Power BI Desktop

**Files:** nenhum — instalação externa.

- [ ] **Passo 1: Baixar e instalar**

Acesse https://www.microsoft.com/pt-br/power-platform/products/power-bi/downloads e baixe
o Power BI Desktop (gratuito, Windows). Rode o instalador com as opções padrão.

- [ ] **Passo 2: Abrir e entrar com sua conta Microsoft**

Abra o Power BI Desktop. Se pedir login, entre com sua conta Microsoft pessoal (mesma que
você usaria pra "Publicar na Web" depois). Se não tiver uma, crie em
https://account.microsoft.com — gratuita, sem cartão.

---

### Task 2: Conectar no Neon e importar as views

**Files:** nenhum — configuração dentro do Power BI Desktop.

**Interfaces:**
- Consumes: as 8 views (`vw_urban_growth_sjrp`, `vw_urban_growth_comparison`,
  `vw_transition_to_urban_sjrp`, `vw_share_pastagem_by_period`, `vw_share_pastagem_by_city`,
  `vw_ranking_pastagem_to_urban`, `vw_agri_composition_over_time`,
  `vw_agri_transitions_by_period`) e a tabela `dim_municipality`, já existentes no Neon.
- Produces: 9 tabelas carregadas no painel "Dados" do Power BI — usadas pelas Tasks 3-7.

- [ ] **Passo 1: Abrir a conexão com o Postgres**

No Power BI Desktop: **Página Inicial → Obter Dados → Banco de dados → PostgreSQL**.

- [ ] **Passo 2: Preencher os dados de conexão**

A partir da connection string do Neon (a mesma de `src/neon_config.py`, no formato
`postgresql://usuario:senha@servidor/banco?sslmode=require`), preencha:
- **Servidor:** a parte entre `@` e `/` (ex.: `ep-winter-cake-acv1c26o.sa-east-1.aws.neon.tech`)
- **Banco de dados:** a parte depois da última `/` (ex.: `neondb`)

Na tela seguinte, usuário e senha são as partes antes do `@` (usuário antes de `:`, senha
depois).

- [ ] **Passo 3: Selecionar as tabelas**

Na janela do Navegador, marque estas 9 tabelas (todas dentro do schema `public`):
`vw_urban_growth_sjrp`, `vw_urban_growth_comparison`, `vw_transition_to_urban_sjrp`,
`vw_share_pastagem_by_period`, `vw_share_pastagem_by_city`, `vw_ranking_pastagem_to_urban`,
`vw_agri_composition_over_time`, `vw_agri_transitions_by_period`, `dim_municipality`.

Clique em **Carregar** (não "Transformar Dados" — não precisamos editar nada no Power
Query).

- [ ] **Passo 4: Verificar**

No painel **Dados** (lado direito), confirme que aparecem as 9 tabelas listadas acima, cada
uma com as colunas esperadas (clique numa tabela pra expandir e ver as colunas).

---

### Task 3: Modelar os relacionamentos

**Files:** nenhum — configuração dentro do Power BI Desktop.

**Interfaces:**
- Consumes: as 9 tabelas da Task 2.
- Produces: relacionamentos que fazem o slicer de cidade (Task 6) filtrar as 3 visualizações
  comparativas ao mesmo tempo.

Por que isso é necessário: sem relacionamento, um slicer baseado numa tabela não filtra
visualizações vindas de outra tabela. `dim_municipality` vira a tabela "mestre" de
município, relacionada às 3 views que comparam cidades.

- [ ] **Passo 1: Abrir a visão de Modelo**

No menu lateral esquerdo do Power BI Desktop, clique no ícone de **Modelo** (três
retângulos conectados).

- [ ] **Passo 2: Criar 3 relacionamentos**

Arraste o campo `municipality` de `dim_municipality` até o campo `municipality` de cada uma
das 3 tabelas abaixo (uma de cada vez):
- `vw_urban_growth_comparison`
- `vw_share_pastagem_by_city`
- `vw_ranking_pastagem_to_urban`

Em cada relacionamento criado, confirme que a cardinalidade ficou **"Um para Muitos"**
(um município em `dim_municipality`, muitas linhas nas outras tabelas).

- [ ] **Passo 3: Verificar**

Na visão de Modelo, confirme visualmente que existem 3 linhas conectando
`dim_municipality` às 3 tabelas listadas no Passo 2.

---

### Task 4: Criar as medidas DAX

**Files:** nenhum — medidas criadas dentro do Power BI Desktop (ficam salvas no `.pbix`).

**Interfaces:**
- Consumes: `vw_ranking_pastagem_to_urban[pastagem_to_urban_ha]`,
  `vw_share_pastagem_by_period[pastagem_ha]`, `vw_share_pastagem_by_period[total_ha]`.
- Produces: 3 medidas (`Ranking DAX`, `Pastagem % (DAX)`, `Total Pastagem para Urbano`) —
  usadas pelas Tasks 6 e 7.

- [ ] **Passo 1: Medida de ranking**

Clique com o botão direito em `vw_ranking_pastagem_to_urban` no painel Dados → **Nova
medida**. Cole exatamente:

```dax
Ranking DAX =
RANKX(
    ALL(vw_ranking_pastagem_to_urban[municipality]),
    CALCULATE(SUM(vw_ranking_pastagem_to_urban[pastagem_to_urban_ha]))
)
```

Essa medida recalcula o ranking por conta própria (via `RANKX`), em vez de só mostrar a
coluna `rank_absoluto` que já vem pronta do SQL — é a parte que demonstra DAX de verdade.

- [ ] **Passo 2: Medida de percentual**

Clique com o botão direito em `vw_share_pastagem_by_period` → **Nova medida**. Cole
exatamente:

```dax
Pastagem % (DAX) =
DIVIDE(
    SUM(vw_share_pastagem_by_period[pastagem_ha]),
    SUM(vw_share_pastagem_by_period[total_ha])
) * 100
```

`DIVIDE()` é a forma correta em DAX de fazer divisão — evita erro se o denominador for
zero, diferente de usar `/` direto.

- [ ] **Passo 3: Medida de total (para o card de destaque)**

Clique com o botão direito em `vw_ranking_pastagem_to_urban` → **Nova medida**. Cole
exatamente:

```dax
Total Pastagem para Urbano (ha) = SUM(vw_ranking_pastagem_to_urban[pastagem_to_urban_ha])
```

- [ ] **Passo 4: Verificar**

No painel Dados, confirme que as 3 medidas aparecem (ícone de calculadora) dentro das
tabelas onde foram criadas.

---

### Task 5: Montar a Página 1 — Crescimento urbano

**Files:** nenhum.

**Interfaces:**
- Consumes: `vw_urban_growth_sjrp`, `vw_urban_growth_comparison`, `dim_municipality`
  (Task 2), relacionamento com `vw_urban_growth_comparison` (Task 3).

- [ ] **Passo 1: Renomear a primeira página**

Clique duas vezes na aba da página (embaixo) e renomeie para **"Crescimento urbano"**.

- [ ] **Passo 2: Gráfico de evolução (pergunta 1)**

Insira um **Gráfico de Linhas**. Campos: Eixo X = `vw_urban_growth_sjrp[year]`, Eixo Y =
`vw_urban_growth_sjrp[area_ha]`. Título: "Evolução da área urbana de SJRP".

- [ ] **Passo 3: Gráfico comparado (pergunta 2)**

Insira outro **Gráfico de Linhas**. Campos: Eixo X = `vw_urban_growth_comparison[year]`,
Eixo Y = `vw_urban_growth_comparison[growth_pct]`, Legenda =
`vw_urban_growth_comparison[municipality]`. Título: "Crescimento comparado (%)".

- [ ] **Passo 4: Slicer de cidade**

Insira um **Segmentação de Dados (Slicer)** usando `dim_municipality[municipality]`. Marque
todas as 6 cidades por padrão. Confirme que mexer no slicer filtra só o gráfico do Passo 3
(o do Passo 2 é fixo em SJRP e não deve reagir — se reagir, o relacionamento da Task 3 foi
aplicado no lugar errado).

- [ ] **Passo 5: Verificar**

Descreva o que aparece na tela, ou tire um print: os dois gráficos de linha, o slicer, e
confirme que filtrar cidade só muda o segundo gráfico.

---

### Task 6: Montar a Página 2 — Origem da expansão

**Files:** nenhum.

**Interfaces:**
- Consumes: `vw_transition_to_urban_sjrp`, `vw_share_pastagem_by_period`,
  `vw_share_pastagem_by_city`, `vw_ranking_pastagem_to_urban`, `dim_municipality`, as
  medidas `Ranking DAX`, `Pastagem % (DAX)`, `Total Pastagem para Urbano (ha)` (Task 4).

- [ ] **Passo 1: Nova página**

Adicione uma página, renomeie para **"Origem da expansão"**.

- [ ] **Passo 2: O que virou área urbana, por década (pergunta 3)**

Insira um **Gráfico de Colunas**. Eixo X = `vw_transition_to_urban_sjrp[origin_class]`,
Eixo Y = `vw_transition_to_urban_sjrp[area_ha]`. Adicione um filtro visual de
`vw_transition_to_urban_sjrp[period]` (só esse gráfico, tipo slicer local ou filtro de
visual) pra poder trocar a década.

- [ ] **Passo 3: % de pastagem por período (pergunta 4)**

Insira um **Gráfico de Colunas**. Eixo X = `vw_share_pastagem_by_period[period]`, Eixo Y =
a medida `Pastagem % (DAX)`. Título: "Dependência de pastagem, por década".

- [ ] **Passo 4: Mesmo padrão nas outras cidades (pergunta 5)**

Insira um **Gráfico de Colunas**. Eixo X = `vw_share_pastagem_by_city[period]`, Legenda =
`vw_share_pastagem_by_city[municipality]`, Eixo Y =
`vw_share_pastagem_by_city[pastagem_pct]`.

- [ ] **Passo 5: Ranking (pergunta 6)**

Insira uma **Tabela**. Colunas: `vw_ranking_pastagem_to_urban[municipality]`, a medida
`Ranking DAX`, `vw_ranking_pastagem_to_urban[pastagem_to_urban_ha]`. Ordene pela coluna
`Ranking DAX`.

- [ ] **Passo 6: Card de destaque**

Insira um **Cartão (Card)** com a medida `Total Pastagem para Urbano (ha)`.

- [ ] **Passo 7: Slicer de cidade**

Insira o mesmo slicer de `dim_municipality[municipality]` da página anterior (pode
copiar/colar da Página 1). Confirme que ele filtra os gráficos dos Passos 4 e 5, mas não os
dos Passos 2, 3 e 6 (que são fixos em SJRP ou agregados).

- [ ] **Passo 8: Verificar**

Descreva/print da página com os 4 gráficos + card + slicer funcionando.

---

### Task 7: Montar a Página 3 — Composição agrícola

**Files:** nenhum.

**Interfaces:**
- Consumes: `vw_agri_composition_over_time`, `vw_agri_transitions_by_period`.

- [ ] **Passo 1: Nova página**

Adicione uma página, renomeie para **"Composição agrícola"**.

- [ ] **Passo 2: Composição ao longo do tempo (pergunta 7)**

Insira um **Gráfico de Linhas**. Eixo X = `vw_agri_composition_over_time[year]`, Eixo Y =
`vw_agri_composition_over_time[area_ha]`, Legenda =
`vw_agri_composition_over_time[class_name]`.

- [ ] **Passo 3: Transições agrícolas por período (pergunta 8)**

Insira uma **Tabela**. Colunas: `vw_agri_transitions_by_period[period]`,
`vw_agri_transitions_by_period[origin_class]`,
`vw_agri_transitions_by_period[destination_class]`,
`vw_agri_transitions_by_period[area_ha]`. Ordene por `area_ha` decrescente.

- [ ] **Passo 4: Verificar**

Descreva/print da página com os 2 elementos.

---

### Task 8: Publicar na Web

**Files:** nenhum — publicação externa.

- [ ] **Passo 1: Salvar o arquivo localmente**

**Arquivo → Salvar Como**. Salve como `dashboard-riopreto.pbix` em qualquer pasta **fora**
do repositório do projeto (ex.: Documentos) — lembrando que esse arquivo não vai pro Git.

- [ ] **Passo 2: Publicar na Web**

**Arquivo → Publicar → Publicar na Web**. Confirme o aviso sobre o relatório ficar público
(esperado — nossos dados já são públicos). Selecione o relatório inteiro (as 3 páginas).

- [ ] **Passo 3: Copiar o link**

Depois de gerado, copie o link (formato `https://app.powerbi.com/view?r=...`) e o código de
incorporação, se aparecer. Guarde o link — é o que entra no README na Task 9.

- [ ] **Passo 4: Verificar**

Abra o link copiado numa aba anônima do navegador (sem estar logado) e confirme que o
relatório aparece, com as 3 páginas navegáveis e os filtros funcionando.

---

### Task 9: Atualizar os READMEs

**Files:**
- Modify: `README.md`
- Modify: `README.en.md`

**Interfaces:**
- Consumes: o link gerado na Task 8.

- [ ] **Passo 1: Adicionar o link nos dois READMEs**

Logo abaixo da linha do link do Streamlit (já existente), adicione uma linha equivalente
pro Power BI, em português no `README.md`:

```markdown
**Dashboard Power BI:** <link gerado na Task 8>
```

E em inglês no `README.en.md`:

```markdown
**Power BI dashboard:** <link gerado na Task 8>
```

- [ ] **Passo 2: Commit e push**

```bash
git add README.md README.en.md
git commit -m "docs: adiciona link do dashboard Power BI publicado"
git push
```
