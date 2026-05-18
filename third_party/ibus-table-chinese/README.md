# IBus Table Chinese Runtime Tables

This directory contains selected runtime tables from `ibus-table-chinese`.

Source:

- Upstream: https://github.com/mike-fabian/ibus-table-chinese
- Debian source packages:
  - `ibus-table-chinese_1.8.12.orig.tar.gz`
  - `ibus-table-chinese_1.8.14.orig.tar.gz`
- Imported files:
  - `tables/quick/quick-classic.txt`
  - `tables/cangjie/cangjie5.txt`

The imported table headers state:

```text
LICENSE = Freely redistributable without restriction
```

PurrType uses `quick-classic.txt` as the fixed `Sucheng` runtime source because Hong Kong user reports and historical comparisons indicate IBus Quick Classic / SCIM quick / GCIN candidate positions match legacy fixed-position Quick/Sucheng ordering more closely than the CNS `simplecj.cin` table.
PurrType uses `cangjie5.txt` as the primary `Cangjie` runtime source, with Rime Cangjie dictionaries kept as fallback coverage.
