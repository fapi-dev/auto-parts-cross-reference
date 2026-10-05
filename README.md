# Auto parts cross-reference database — sample, schema and load commands

This repository holds a sample of the FAPI auto parts cross-reference database. A cross-reference is a link between two part numbers recorded as replacing each other. The numbers belong to original (OE) and aftermarket parts. The data is meant for sites that sell auto parts, for inventory and accounting systems, and for CRMs.

The sample uses the file layout of the SQL archive of the full database: three text files and one schema. You can load it into MySQL, MariaDB or PostgreSQL, run the example queries, and see the layout the full database comes in.

## Files

| File | Rows | What it holds |
|---|---|---|
| `scheme.sql` | — | the three tables, their keys and indexes; one file for all three servers |
| `manufacturer_list.txt` | 1,506 | brands: makers of parts, of vehicles and of machinery |
| `product_list.txt` | 13,869 | part numbers |
| `analog_list.txt` | 22,550 | crosses between part numbers |

The data files are UTF-8 without a byte-order mark. One row per line, lines end with LF, there
is no header row and no quoting: whatever stands between two separators is the value.
`manufacturer_list.txt` and `analog_list.txt` separate fields with `;`, `product_list.txt` with
a TAB.

## What the sample covers

The sample has 1,133 parts brands with up to 10 crosses each. 6 brands have fewer.

- 11,275 crosses, each stored from both ends (22,550 rows in `analog_list.txt`)
- 13,869 part numbers
- 1,506 brand rows: the parts brands plus 373 makers of vehicles, machinery and parts

A cross is included when the other number is listed as a direct equivalent of the article. References valid for some countries only, or carrying a reservation (part of a kit, needs adjusting, more or fewer parts), are left out. The first ten crosses per brand are taken in article-number order, so the sample is the same each time it is produced.

The rating counts the sources that confirm a cross, less those that dispute it. Each cross here has one source, so the rating is 1. The ids are the sample's own and differ from those in the full database.

## Load into MySQL or MariaDB

Start the client with local files allowed, from the directory that holds the files:

```
mysql --local-infile=1 -u <user> -p
```

```
CREATE DATABASE fapi_db CHARACTER SET utf8mb4;
USE fapi_db;
SOURCE scheme.sql;
LOAD DATA LOCAL INFILE 'manufacturer_list.txt' INTO TABLE manufacturer_list CHARACTER SET utf8mb4 FIELDS TERMINATED BY ';' ESCAPED BY '' LINES TERMINATED BY '\n' (i, ds, da);
LOAD DATA LOCAL INFILE 'product_list.txt' INTO TABLE product_list CHARACTER SET utf8mb4 FIELDS TERMINATED BY '\t' ESCAPED BY '' LINES TERMINATED BY '\n' (i, mfi, ns, n, d, tp, upd);
LOAD DATA LOCAL INFILE 'analog_list.txt' INTO TABLE analog_list CHARACTER SET utf8mb4 FIELDS TERMINATED BY ';' ESCAPED BY '' LINES TERMINATED BY '\n' (i, mfi, ns, pi, pai, r);
```

- The server has to allow local files as well. MySQL 8.4 ships with that switched off, and
  the load is refused until an administrator runs `SET GLOBAL local_infile = 1;`. MariaDB
  allows it out of the box.
- `ESCAPED BY ''` makes a backslash inside a value plain data.
- Files written on Windows end their lines with CR LF: load those with
  `LINES TERMINATED BY '\r\n'`.

## Load into PostgreSQL

Start `psql` from the directory that holds the files:

```
psql -U <user> -d postgres
```

```
CREATE DATABASE fapi_db;
\c fapi_db
\i scheme.sql
\copy manufacturer_list (i, ds, da) FROM 'manufacturer_list.txt' WITH (FORMAT csv, DELIMITER ';', QUOTE E'\x01', ENCODING 'UTF8')
\copy product_list (i, mfi, ns, n, d, tp, upd) FROM 'product_list.txt' WITH (FORMAT csv, DELIMITER E'\t', QUOTE E'\x01', FORCE_NOT_NULL (n, d), ENCODING 'UTF8')
\copy analog_list (i, mfi, ns, pi, pai, r) FROM 'analog_list.txt' WITH (FORMAT csv, DELIMITER ';', QUOTE E'\x01', ENCODING 'UTF8')
```

- Each `\copy` is one line.
- The files have no quoting, so the commands name a quote character that never occurs in
  them: a `"` or a backslash inside a value stays what it is. The default text format would
  read a backslash as an escape.
- `FORCE_NOT_NULL (n, d)` loads an unknown spelling or part name as an empty string, as MySQL
  does, not as NULL.
- Files with CR LF line ends load with the same commands.

## Schema

`scheme.sql` creates the three tables, their primary keys and the indexes the example queries use. One file serves MySQL, MariaDB and PostgreSQL; the load commands above run it first.

```sql
-- FAPI cross-reference base: the three tables of the SQL archive.
-- One file for MySQL, MariaDB and PostgreSQL.

CREATE TABLE manufacturer_list (
    i integer NOT NULL,
    ds character varying(255) NOT NULL,
    da character varying(255) NOT NULL
);

CREATE TABLE product_list (
    i bigint NOT NULL,
    mfi integer NOT NULL,
    ns character varying(105) NOT NULL,
    n character varying(255),
    d character varying(255),
    tp integer NOT NULL,
    upd bigint DEFAULT 0 NOT NULL
);

CREATE TABLE analog_list (
    i bigint NOT NULL,
    mfi integer NOT NULL,
    ns character varying(105) NOT NULL,
    pi bigint NOT NULL,
    pai bigint NOT NULL,
    r integer NOT NULL
);

ALTER TABLE manufacturer_list ADD CONSTRAINT pk_manufacturer_list_i PRIMARY KEY (i);
ALTER TABLE product_list ADD CONSTRAINT pk_product_list_i PRIMARY KEY (i);
ALTER TABLE analog_list ADD CONSTRAINT pk_analog_list_i PRIMARY KEY (i);

CREATE INDEX k_manufacturer_list_da ON manufacturer_list (da);
CREATE INDEX k_product_list_ns ON product_list (ns);
CREATE INDEX k_analog_list_ns ON analog_list (ns);
CREATE INDEX k_analog_list_pai ON analog_list (pai);
```

## Example queries

Numbers are searched by their normalised form, the column `ns`: lower case, letters and digits
only. `0 001 106 014`, `0001106014` and `0-001-106-014` are all `0001106014`. Brands are matched
the same way by `da`, in upper case: `MERCEDES-BENZ` is `MERCEDESBENZ`.

Every cross of a number, whichever brand the number belongs to:

```sql
SELECT m.ds AS brand, p.n AS part_number,
       xm.ds AS cross_brand, x.n AS cross_number, x.d AS part, a.r AS rating
FROM analog_list a
JOIN product_list p ON p.i = a.pi
JOIN manufacturer_list m ON m.i = p.mfi
JOIN product_list x ON x.i = a.pai
JOIN manufacturer_list xm ON xm.i = x.mfi
WHERE a.ns = '0001106014'
ORDER BY brand, cross_brand, cross_number;
```

The crosses of a number of one brand — two brands may use the same number for different
parts:

```sql
SELECT xm.ds AS cross_brand, x.n AS cross_number, x.d AS part, a.r AS rating
FROM analog_list a
JOIN product_list x ON x.i = a.pai
JOIN manufacturer_list xm ON xm.i = x.mfi
WHERE a.ns = '0001106014'
  AND a.mfi = (SELECT i FROM manufacturer_list WHERE da = 'BOSCH')
ORDER BY cross_brand, cross_number;
```

Only the original numbers a part replaces:

```sql
SELECT xm.ds AS maker, x.n AS original_number
FROM analog_list a
JOIN product_list x ON x.i = a.pai
JOIN manufacturer_list xm ON xm.i = x.mfi
WHERE a.ns = '0001106014'
  AND a.mfi = (SELECT i FROM manufacturer_list WHERE da = 'BOSCH')
  AND x.tp = 10
ORDER BY maker, original_number;
```

From the other end — which parts replace an original number:

```sql
SELECT xm.ds AS brand, x.n AS part_number, x.d AS part
FROM analog_list a
JOIN product_list x ON x.i = a.pai
JOIN manufacturer_list xm ON xm.i = x.mfi
WHERE a.ns = 'a0051513801'
  AND a.mfi = (SELECT i FROM manufacturer_list WHERE da = 'MERCEDESBENZ')
ORDER BY brand, part_number;
```

## Field reference

`manufacturer_list` — a brand:

| Column | Meaning |
|---|---|
| `i` | id of the brand |
| `ds` | name of the brand |
| `da` | the name normalised for matching: upper case, letters and digits only |

`product_list` — a part number of a brand:

| Column | Meaning |
|---|---|
| `i` | id of the part number |
| `mfi` | its brand, `manufacturer_list.i` |
| `ns` | the number normalised for search: lower case, letters and digits only; one row per brand and `ns` |
| `n` | the number as its maker writes it, with spaces, dots and dashes; empty when the spelling is not known |
| `d` | what the part is; empty when not known |
| `tp` | `50` a number from the brand's own catalogue, `10` an original (OE) number, `-1` not stated |
| `upd` | last update, Unix time in milliseconds; `0` when not known |

`analog_list` — a cross, seen from one of its two ends:

| Column | Meaning |
|---|---|
| `i` | id of the row |
| `mfi` | brand of the part the row starts from, the same as that part's `product_list.mfi` |
| `ns` | normalised number of that part, the same as its `product_list.ns`; a number is looked up here without a join |
| `pi` | the part the row starts from, `product_list.i` |
| `pai` | the part it crosses to, `product_list.i` |
| `r` | rating: how many sources confirm the cross, less those that dispute it. Every cross of this sample has one source, so it is `1` |

## Tested on

| Server | Version | Client |
|---|---|---|
| MySQL | 8.4.11 | `mysql` 8.4.11 |
| MariaDB | 11.8.6 | `mariadb` 15.2, the one shipped with the server |
| PostgreSQL | 18.4 | `psql` 18.4 |

On each of them the schema was created and the three files were loaded with the commands above.
The row counts matched the table at the top, every table read back equal to its file byte for
byte, and the four queries gave the same rows on all three servers.

## Licence

The schema and the load commands are under the MIT License (`LICENSE`). The sample data is for evaluation only (`DATA-LICENSE.md`). You may download it, load it and query it to evaluate the format and the data. You may not redistribute it, publish it elsewhere or use it in a product or a service.

## Full dataset

As of 4 February 2026 the full database holds 968M+ cross-reference records, 41M+ part numbers (OE and aftermarket) and 11,437 brands and trade marks. The collection began in 2015. It is delivered in one of three formats: text, Excel or SQL. The SQL archive is for MySQL and PostgreSQL. One brand can be bought as an export on its own. An update subscription exists for clients who have bought the full database. Prices and the way to buy are on the [product page](https://iisis.ru/en/auto-parts-cross-reference-database/).
