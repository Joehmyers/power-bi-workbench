"""Generate the Brewline demo dataset: a fictional UK coffee chain.

Writes five CSV files next to this script, which the Brewline semantic model
reads through its DataSource parameter:

  date.csv     calendar, whole years covering the sales period
  store.csv    14 shops across the UK (two open partway through)
  product.csv  14 products in four categories
  channel.csv  In store, Mobile order, Delivery
  sales.csv    units, net sales and cost by date x store x product
  traffic.csv  orders by date x store x channel

The output is deterministic for a given --end date, so re-running it only
changes the files when the period changes. Extend the data to "today" and
push to demonstrate a refresh picking up new rows:

  python3 projects/Brewline/data/generate_data.py --end 2026-11-30
"""

import argparse
import csv
import math
import random
from datetime import date, timedelta
from pathlib import Path

OUT = Path(__file__).resolve().parent
START = date(2025, 1, 1)

# key, store, city, region, country, format, open date, latitude, longitude, size
STORES = [
    (1, "London Kings Cross", "London", "London", "England", "Station", date(2019, 3, 1), 51.5308, -0.1238, 1.45),
    (2, "London Shoreditch", "London", "London", "England", "High Street", date(2020, 6, 15), 51.5262, -0.0786, 1.20),
    (3, "London Canary Wharf", "London", "London", "England", "Office", date(2021, 1, 10), 51.5054, -0.0235, 1.30),
    (4, "Manchester Northern Quarter", "Manchester", "North West", "England", "High Street", date(2019, 9, 1), 53.4839, -2.2370, 1.10),
    (5, "Manchester Piccadilly", "Manchester", "North West", "England", "Station", date(2022, 2, 1), 53.4774, -2.2309, 1.25),
    (6, "Leeds Briggate", "Leeds", "Yorkshire and the Humber", "England", "High Street", date(2020, 3, 1), 53.7983, -1.5420, 0.95),
    (7, "Birmingham New Street", "Birmingham", "West Midlands", "England", "Station", date(2021, 5, 1), 52.4778, -1.8990, 1.15),
    (8, "Bristol Harbourside", "Bristol", "South West", "England", "High Street", date(2022, 7, 1), 51.4500, -2.5970, 0.90),
    (9, "Edinburgh Princes Street", "Edinburgh", "Scotland", "Scotland", "High Street", date(2020, 10, 1), 55.9521, -3.1965, 1.05),
    (10, "Glasgow Buchanan Street", "Glasgow", "Scotland", "Scotland", "High Street", date(2023, 4, 1), 55.8616, -4.2531, 0.85),
    (11, "Cardiff Queen Street", "Cardiff", "Wales", "Wales", "High Street", date(2023, 9, 1), 51.4816, -3.1750, 0.80),
    (12, "Newcastle Grey Street", "Newcastle", "North East", "England", "High Street", date(2024, 3, 1), 54.9718, -1.6118, 0.75),
    (13, "Cambridge Market Square", "Cambridge", "East of England", "England", "Campus", date(2025, 5, 12), 52.2053, 0.1192, 0.90),
    (14, "Belfast Cathedral Quarter", "Belfast", "Northern Ireland", "Northern Ireland", "High Street", date(2026, 2, 2), 54.6020, -5.9290, 0.80),
]

# Year-on-year trend per store, so the store table has winners and laggards.
STORE_TREND = {1: 0.05, 2: 0.03, 3: -0.02, 4: 0.04, 5: 0.11, 6: 0.02, 7: 0.06,
               8: -0.04, 9: 0.03, 10: 0.07, 11: 0.05, 12: 0.09, 13: 0.0, 14: 0.0}

# key, product, category, subcategory, price, cost, base daily units, season
PRODUCTS = [
    (1, "Flat White", "Coffee", "Espresso", 3.40, 0.80, 70, "flat"),
    (2, "Latte", "Coffee", "Espresso", 3.50, 0.85, 60, "flat"),
    (3, "Cappuccino", "Coffee", "Espresso", 3.40, 0.80, 35, "flat"),
    (4, "Americano", "Coffee", "Espresso", 2.90, 0.55, 40, "flat"),
    (5, "Batch Brew", "Coffee", "Filter", 2.60, 0.45, 25, "flat"),
    (6, "Iced Latte", "Coffee", "Cold Drinks", 3.80, 0.95, 15, "summer"),
    (7, "English Breakfast Tea", "Tea and Other", "Tea", 2.40, 0.30, 20, "winter"),
    (8, "Hot Chocolate", "Tea and Other", "Chocolate", 3.30, 0.75, 15, "winter"),
    (9, "Croissant", "Food", "Bakery", 2.60, 0.90, 30, "flat"),
    (10, "Cinnamon Bun", "Food", "Bakery", 3.20, 1.05, 18, "flat"),
    (11, "Bacon Roll", "Food", "Hot Food", 4.50, 1.60, 20, "weekend"),
    (12, "Cheese Toastie", "Food", "Hot Food", 5.20, 1.90, 15, "winter"),
    (13, "House Blend Beans 250g", "Retail", "Beans", 8.50, 3.40, 3, "christmas"),
    (14, "Brewline Keep Cup", "Retail", "Merchandise", 12.00, 4.20, 1, "christmas"),
]
COFFEE_CATEGORIES = {"Coffee"}

CHANNELS = [(1, "In store", 1), (2, "Mobile order", 2), (3, "Delivery", 3)]

PRICE_RISE = date(2026, 1, 5)    # 6% on drinks
BEAN_COST_RISE = date(2025, 6, 1)  # coffee cost +12%


def season(kind: str, d: date) -> float:
    angle = 2 * math.pi * (d.timetuple().tm_yday - 196) / 365.25  # peaks mid-July
    if kind == "summer":
        return max(0.25, 1 + 1.2 * math.cos(angle))
    if kind == "winter":
        return max(0.4, 1 - 0.55 * math.cos(angle))
    if kind == "weekend":
        return 1.6 if d.weekday() >= 5 else 0.85
    if kind == "christmas":
        if d.month == 12 and d.day <= 24:
            return 4.0
        return 1.4 if d.month == 11 else 1.0
    return 1.0


def footfall(fmt: str, d: date) -> float:
    weekend = d.weekday() >= 5
    bank_holiday = (d.month, d.day) in {(1, 1), (12, 25), (12, 26)}
    if bank_holiday:
        return 0.15
    if fmt == "Station":
        return 0.6 if weekend else 1.15
    if fmt == "Office":
        return 0.35 if weekend else 1.3
    if fmt == "Campus":
        term = d.month not in (7, 8) and not (d.month == 12 and d.day > 18)
        return (0.7 if weekend else 1.1) * (1.0 if term else 0.45)
    return 1.3 if weekend else 0.95  # High Street


def ramp(open_date: date, d: date) -> float:
    """New shops take about three months to build up trade."""
    days = (d - open_date).days
    return min(1.0, 0.55 + 0.45 * days / 90) if days < 90 else 1.0


def write(name: str, header: list, rows: list) -> None:
    with open(OUT / name, "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(header)
        w.writerows(rows)
    print(f"{name}: {len(rows):,} rows")


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("--end", type=date.fromisoformat, default=date(2026, 10, 31),
                   help="last sales date, inclusive (default 2026-10-31)")
    end = p.parse_args().end
    rng = random.Random(20250101)

    cal_end = date(end.year, 12, 31)
    dates = [START + timedelta(n) for n in range((cal_end - START).days + 1)]
    write("date.csv",
          ["Date", "Year", "Quarter", "Year Quarter", "Month Number", "Month", "Month Start",
           "Year Month", "Year Month Number", "Weekday Number", "Weekday", "Is Weekend"],
          [[d.isoformat(), d.year, f"Q{(d.month - 1) // 3 + 1}", f"{d.year} Q{(d.month - 1) // 3 + 1}",
            d.month, d.strftime("%b"), d.replace(day=1).isoformat(), d.strftime("%b %Y"),
            d.year * 100 + d.month, d.isoweekday(), d.strftime("%a"), str(d.weekday() >= 5).lower()]
           for d in dates])

    write("store.csv",
          ["Store Key", "Store", "City", "Region", "Country", "Format", "Open Date", "Latitude", "Longitude"],
          [[k, s, c, r, co, f, o.isoformat(), la, lo] for k, s, c, r, co, f, o, la, lo, _ in STORES])
    write("product.csv",
          ["Product Key", "Product", "Category", "Subcategory", "List Price"],
          [[k, n, c, s, f"{pr:.2f}"] for k, n, c, s, pr, *_ in PRODUCTS])
    write("channel.csv", ["Channel Key", "Channel", "Channel Order"], [list(c) for c in CHANNELS])

    sales, traffic = [], []
    for d in (START + timedelta(n) for n in range((end - START).days + 1)):
        years_in = (d - START).days / 365.25
        for key, _, _, _, _, fmt, opened, _, _, size in STORES:
            if d < opened:
                continue
            trade = size * footfall(fmt, d) * ramp(opened, d) * (1 + STORE_TREND[key]) ** years_in
            trade *= rng.gauss(1.0, 0.08)  # weather, events
            units_today = 0
            for pkey, _, cat, _, price, cost, base, kind in PRODUCTS:
                mean = base * trade * season(kind, d)
                qty = max(0, round(rng.gauss(mean, math.sqrt(mean) * 1.2)))
                if qty == 0:
                    continue
                unit_price = price * (1.06 if d >= PRICE_RISE and cat != "Retail" else 1.0)
                unit_cost = cost * (1.12 if d >= BEAN_COST_RISE and cat in COFFEE_CATEGORIES else 1.0)
                sales.append([d.isoformat(), key, pkey, qty, f"{qty * unit_price:.2f}", f"{qty * unit_cost:.2f}"])
                units_today += qty
            # Mobile ordering grows from 12% to ~24%; stations have no delivery.
            orders = round(units_today / rng.uniform(1.5, 1.7))
            mobile = min(0.30, 0.12 + 0.06 * years_in) * rng.uniform(0.9, 1.1)
            delivery = 0.0 if fmt == "Station" else 0.07 * rng.uniform(0.8, 1.2)
            split = {2: round(orders * mobile), 3: round(orders * delivery)}
            split[1] = orders - split[2] - split[3]
            traffic += [[d.isoformat(), key, ck, n] for ck, n in sorted(split.items()) if n > 0]

    write("sales.csv", ["Date", "Store Key", "Product Key", "Quantity", "Net Sales", "Cost"], sales)
    write("traffic.csv", ["Date", "Store Key", "Channel Key", "Order Count"], traffic)


if __name__ == "__main__":
    main()
