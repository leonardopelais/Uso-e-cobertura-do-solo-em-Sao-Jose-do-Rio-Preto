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
