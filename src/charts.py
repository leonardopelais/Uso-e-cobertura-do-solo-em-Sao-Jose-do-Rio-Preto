import pandas as pd
import matplotlib.pyplot as plt
from db import get_connection

OUT_DIR = "outputs/figuras"


def chart_urban_growth_comparison():
    conn = get_connection()
    df = pd.read_sql("SELECT * FROM vw_urban_growth_comparison", conn)
    conn.close()
    fig, ax = plt.subplots()
    for municipality, group in df.groupby("municipality"):
        ax.plot(group["year"], group["growth_pct"], label=municipality)
    ax.set_xlabel("Ano")
    ax.set_ylabel("Crescimento da área urbana (%)")
    ax.set_title("Crescimento da área urbana — SJRP vs. cidades de porte similar")
    ax.legend(fontsize="small")
    fig.savefig(f"{OUT_DIR}/urban_growth_comparison.png", dpi=150, bbox_inches="tight")


def chart_share_pastagem_by_period():
    conn = get_connection()
    df = pd.read_sql("SELECT * FROM vw_share_pastagem_by_period", conn)
    conn.close()
    df = df.sort_values("period")
    fig, ax = plt.subplots()
    ax.bar(df["period"], df["pastagem_pct"])
    ax.set_ylabel("% da área urbana nova vinda de pastagem")
    ax.set_title("SJRP: dependência de pastagem na expansão urbana, por década")
    fig.savefig(f"{OUT_DIR}/share_pastagem_by_period.png", dpi=150, bbox_inches="tight")


if __name__ == "__main__":
    chart_urban_growth_comparison()
    chart_share_pastagem_by_period()
    print("gráficos salvos em outputs/figuras/")
