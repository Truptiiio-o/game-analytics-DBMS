# python/load_data.py  -- run from the project root:  python python/load_data.py
import duckdb
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
con = duckdb.connect(str(ROOT / "game.db"))

for t in ["player_profile", "player_day", "purchase", "currency_spend", "ad_view"]:
    con.execute(f"""
        CREATE OR REPLACE TABLE {t} AS
        SELECT * FROM read_csv_auto('{(ROOT / "data" / (t + ".csv")).as_posix()}')
    """)
    print(t, con.execute(f"SELECT COUNT(*) FROM {t}").fetchone()[0], "rows")