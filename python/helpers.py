# python/helpers.py
import duckdb, pandas as pd
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
con = duckdb.connect(str(ROOT / "game.db"))

def q(sql: str) -> pd.DataFrame:
    return con.execute(sql).df()

def run_sql_file(name: str) -> pd.DataFrame:
    return q((ROOT / "sql" / name).read_text())