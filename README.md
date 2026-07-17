# COBOL Payment System

A small COBOL batch program that reads a list of financial transactions, validates
each one against a master list of accounts and a few configuration rules, applies the
approved ones to the in-memory account balances, and writes out approval, rejection,
and summary reports.

This was built as a learning project to get familiar with COBOL file handling, tables,
and batch processing.

## What it does

The program (`src/PAYMENTPROC.cob`) runs in three phases:

1. **Load** – reads configuration and account data into memory.
2. **Process** – reads each transaction, validates it, and applies it if valid.
3. **Report** – writes approved/rejected logs and a summary report.

Each transaction is either a `DEBIT` (money out) or a `CREDIT` (money in). A
transaction is **rejected** if any of these are true:

- the amount is missing or not a number,
- it is a `DEBIT` larger than `MAX_DEBIT`,
- it is a `CREDIT` but credits are disabled in the config,
- the account ID does not exist,
- it is a `DEBIT` for more than the account's current balance (insufficient funds).

Approved transactions update the account's balance in memory for the rest of the run.

## Project layout

```
.
├── src/
│   └── PAYMENTPROC.cob     # main program
├── data/                   # input files
│   ├── ACCOUNTS.TXT        # account ID + starting balance
│   ├── CONFIG.TXT          # MAX_DEBIT and ALLOW_CREDIT settings
│   └── TRANSACTIONS.TXT    # transactions to process
├── output/                 # generated on each run
│   ├── APPROVED.TXT        # one line per approved transaction
│   ├── REJECTED.TXT        # one line per rejected transaction + reason
│   └── REPORT.TXT          # totals summary
├── scripts/
│   └── run.sh              # build + run helper (placeholder)
└── docs/                   # notes
```

## Input file formats

**`data/ACCOUNTS.TXT`** — account ID (6 digits, zero-padded) and starting balance,
separated by a space:

```
000001 1000
000002 500
```

**`data/CONFIG.TXT`** — `KEY=VALUE` per line:

```
MAX_DEBIT=500
ALLOW_CREDIT=Y
```

- `MAX_DEBIT` – largest allowed single debit amount.
- `ALLOW_CREDIT` – `Y` to allow credits, `N` to reject them.

**`data/TRANSACTIONS.TXT`** — account ID, type (`DEBIT`/`CREDIT`), and amount:

```
000001 DEBIT 200
000004 CREDIT 100
```

## Output files

- **`output/APPROVED.TXT`** – one line per approved transaction with the amount.
- **`output/REJECTED.TXT`** – one line per rejected transaction with the reason
  (e.g. `EXCEEDS MAX DEBIT`, `INSUFFICIENT FUNDS`, `ACCOUNT NOT FOUND`).
- **`output/REPORT.TXT`** – total, approved, and rejected counts.

## Building and running

This project uses [GnuCOBOL](https://gnucobol.sourceforge.io/) (`cobc`).

Install GnuCOBOL (Ubuntu/Debian example):

```sh
sudo apt-get install gnucobol
```

Compile and run:

```sh
cobc -x -o paymentproc src/PAYMENTPROC.cob
./paymentproc
```

The source is written in fixed-format COBOL, which is the `cobc` default, so no
extra format flag is needed.

> Note: the program uses relative paths like `data/CONFIG.TXT` and `output/APPROVED.TXT`,
> so run it from the project root so those folders are found.

A prebuilt Windows binary (`paymentproc.exe`) is also included in the repo.

## Notes / limitations

- Balances and amounts are whole numbers only (no cents).
- The account table holds up to 1000 accounts.
- Output files are overwritten on every run.
