# COBOL Payment Processor

A batch transaction-processing program written in COBOL 85 (compiled with GnuCOBOL). It simulates a core banking/payment switch by reconciling a stream of debit and credit transactions against a sorted master account ledger, applying business rules from a runtime config file, and producing audit-ready reports.

## What it demonstrates

- **Sequential file I/O** with explicit `FILE STATUS` handling.
- **In-memory table processing** with `SEARCH ALL` (binary search) for account resolution.
- **Runtime configuration** (`data/CONFIG.TXT`) for rule thresholds without recompiling.
- **Defensive data parsing** using `FUNCTION NUMVAL()` to avoid S0C7-style data exceptions.
- **Batch reporting**: approved list, rejected list with reason codes, updated ledger, and summary metrics.

## Project structure

```
├── src/
│   └── PAYMENTPROC.cob           # Main COBOL source
├── data/
│   ├── CONFIG.TXT                # Runtime rules
│   ├── ACCOUNTS.TXT              # Sorted master ledger (CSV)
│   └── TRANSACTIONS.TXT          # Incoming transaction batch (CSV)
├── output/
│   ├── APPROVED.TXT              # Approved transactions with new balance
│   ├── REJECTED.TXT              # Rejected transactions with reason
│   ├── ACCOUNTS-UPDATED.TXT      # Updated master ledger
│   └── REPORT.TXT                # Batch summary
├── scripts/
│   ├── run.sh                    # Linux/macOS build + run
│   └── run.bat                   # Windows build + run
└── generate_data.py              # Optional test-data generator
```

## Input format

Accounts (`ACCOUNTS.TXT`) must be sorted ascending by Account ID:

```
000001,1000
000002,300
000003,50
```

Transactions (`TRANSACTIONS.TXT`):

```
000001,DEBIT,200
000002,CREDIT,500
000003,DEBIT,99999
```

## Sample output

With the sample input above, the `output/` directory will contain:

`APPROVED.TXT`:

```
APPROVED: 000001 NEW BALANCE: 000000800
APPROVED: 000002 NEW BALANCE: 000000800
```

`REJECTED.TXT`:

```
REJECTED: 000003 REASON: EXCEEDS MAX DEBIT
REJECTED: 000004 REASON: ACCOUNT NOT FOUND
REJECTED: 000002 REASON: INVALID TRANSACTION TYPE
```

`ACCOUNTS-UPDATED.TXT`:

```
000001,000000800
000002,000000800
000003,000000050
```

`REPORT.TXT`:

```
TOTAL TRANSACTIONS: 000005
TOTAL APPROVED:     000002
TOTAL REJECTED:     000003
```

## Configuration (`data/CONFIG.TXT`)

```
MAX_DEBIT=500
ALLOW_CREDIT=Y
```

| Parameter      | Type       | Description                                |
| -------------- | ---------- | ------------------------------------------ |
| `MAX_DEBIT`    | Numeric    | Maximum amount allowed for a single debit. |
| `ALLOW_CREDIT` | `Y` or `N` | Global switch for credit transactions.     |

## Getting started

### Prerequisites

- [GnuCOBOL](https://gnucobol.sourceforge.io/)
- Python 3.x (only for `generate_data.py`)

### 1. Generate sample data (optional)

```bash
python generate_data.py
```

This creates 1,000 sorted accounts and 1,500 random transactions in `data/`.

### 2. Compile

Linux / macOS:

```bash
cobc -x src/PAYMENTPROC.cob -o PAYMENTPROC
```

Windows:

```cmd
cobc -x src\PAYMENTPROC.cob -o PAYMENTPROC.exe
```

Or use the provided helper scripts:

```bash
# Linux / macOS
chmod +x scripts/run.sh
./scripts/run.sh

# Windows
scripts\run.bat
```

### 3. Run

Make sure you are in the project root so the program can locate `data/` and `output/`.

```bash
./PAYMENTPROC
```

On Windows:

```cmd
PAYMENTPROC.exe
```

## Notes

- The account master file **must** be sorted by `Account ID` because the program uses `SEARCH ALL` (binary search).
- Output files are written to `output/` each run; they are not committed to the repo.
