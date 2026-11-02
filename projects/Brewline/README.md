# Brewline

Demo PBIP project for the workbench: a fictional UK coffee chain with 14 shops,
14 products and three order channels, January 2025 to October 2026. All data is
dummy data from [`data/generate_data.py`](data/generate_data.py).

## Open it in Power BI Desktop (Windows)

1. Clone or pull the repository, then open `projects/Brewline/Brewline.pbip`.
2. The project carries no cached data, so select **Refresh**. When asked how to
   connect to `raw.githubusercontent.com`, choose **Anonymous**.
3. The report opens on the **Overview** page, filtered to 2026 by the year
   slicer.

The `DataSource` parameter (Transform data > Edit parameters) decides where
the CSV files come from:

| Value | Reads from |
|---|---|
| `https://raw.githubusercontent.com/Joehmyers/power-bi-workbench/main/projects/Brewline/data/` (default) | The CSVs pushed to `main` on GitHub |
| A local folder ending in `\`, e.g. `C:\src\power-bi-workbench\projects\Brewline\data\` | The CSVs in your clone, no network needed |

The parameter suits Desktop. Before scheduling refresh in the Power BI service,
drop the `File.Contents` branch from the partitions so the service sees a
single static web source.

## Model

| Table | Grain | Rows |
|---|---|---|
| `Sales` | date x store x product: units, net sales, cost | ~120k |
| `Traffic` | date x store x channel: orders | ~25k |
| `Date` | day, whole years; marked as the date table | 730 |
| `Store`, `Product`, `Channel` | dimensions | 14, 14, 3 |
| `_Measures` | all report measures | |

Stories planted in the data: two shops open during the period (Cambridge in
May 2025, Belfast in February 2026); coffee costs rise 12% from June 2025 and
prices rise 6% from January 2026, so gross margin dips and recovers; app
ordering grows from about 12% to 24% of orders; stations sell no delivery.

`Traffic` has no product grain, so `Orders` and `Avg Order Value` do not
respond to product filters.

## Updating the data

```bash
python3 projects/Brewline/data/generate_data.py --end 2026-11-30
```

The generator is deterministic for a given `--end` date. Push the new CSVs and
select **Refresh** in Desktop to load them.

## Demo briefs

Briefs that exercise the workbench on this project:

- Add a `Revenue MTD` measure and a "Margin by month" line chart to Overview.
- Add a Channels page: orders by channel by month, and mobile share by store.
- Add a `Like-for-like Revenue YoY %` measure that only counts shops open in
  both periods, and use it in the shop table.
