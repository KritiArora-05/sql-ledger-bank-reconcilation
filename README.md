# Ledger vs Bank Reconciliation in SQL

A small SQL project where I match a company's ledger against its bank statement and find the differences.

## Why I did this
At month-end, the books and the bank statement should agree. When they don't, someone has to find out why.
I did reconciliations in my accounts internship, and here I wanted to do the same thing in SQL.

## Data
The data is **simulated** (made up by me, not from a real company). I planted some errors in it on purpose,
so I could check that my queries find them.

| Table | Rows | What it is |
|---|---|---|
| vendors | 10 | Suppliers |
| ledger | 1,015 | Invoices booked in the books (1,000 unique, 15 posted twice) |
| bank_statement | 988 | Payments and charges at the bank |

The ledger and bank statement are matched using `reference_no` (the invoice number).

## What I used
SQLite (DB Browser for SQLite). SQL concepts: JOIN, LEFT JOIN, GROUP BY, HAVING, subqueries, UNION ALL,
COUNT, SUM, ROUND, ABS, DISTINCT.

## How to run it
1. Open DB Browser for SQLite and create a new database.
2. In the Execute SQL tab, run `01_setup_database.sql`, then click Write Changes.
3. Run the queries in `02_reconciliation_queries.sql` one at a time.

## Results
Ledger total: 127,634,734.79
Bank statement total: 121,868,872.85
Gap: 5,765,861.94

| What I found | Items | Effect on (ledger minus bank) |
|---|---|---|
| Invoices in ledger but not in bank | 30 | +3,762,632.26 |
| Invoices posted twice in the ledger | 15 | +2,032,453.65 |
| Amount mismatches (net) | 25 | +20,380.50 |
| Bank charges not in ledger | 18 | -49,604.47 |
| **Total** | | **5,765,861.94** |

These four add up to the full gap.

I also found 20 invoices that were paid correctly but more than 7 days after booking (longest was 30 days).
These don't change any totals, so they are not in the table.

## What I learned
- You have to check both ways: something can be missing from the bank or missing from the books.
- Duplicates and wrong amounts don't show up if you only look for missing entries.
- Adding up the findings to match the original gap is a good way to check nothing was missed.

## Limitations
The data is simulated, so real data would be messier (for example partial payments or invoice numbers typed differently).

