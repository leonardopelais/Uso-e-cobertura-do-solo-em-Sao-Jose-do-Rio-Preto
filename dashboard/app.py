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
