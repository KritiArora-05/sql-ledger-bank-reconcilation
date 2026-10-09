-- Ledger vs bank reconciliation queries (SQLite)
-- Run 01_setup_database.sql first, then run these one at a time.

-- 1. Sanity check: row count and total of each table
SELECT 'ledger' AS source, COUNT(*) AS rows_, ROUND(SUM(amount),2) AS total FROM ledger
UNION ALL
SELECT 'bank_statement', COUNT(*), ROUND(SUM(amount),2) FROM bank_statement;

-- 2. Invoices in the ledger with no payment in the bank
-- LEFT JOIN keeps all ledger rows. If there is no bank match, the bank columns are NULL.
SELECT l.entry_id, l.entry_date, v.vendor_name, l.reference_no, l.amount
FROM ledger l
JOIN vendors v ON v.vendor_id = l.vendor_id
LEFT JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE b.bank_txn_id IS NULL
ORDER BY l.amount DESC;

-- 2b. Count and total of those unpaid invoices
SELECT COUNT(*) AS unpaid_entries,
       ROUND(SUM(l.amount), 2) AS unpaid_total
FROM ledger l
LEFT JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE b.bank_txn_id IS NULL;

-- 3. Bank transactions with no ledger entry (same idea, tables swapped)
SELECT b.bank_txn_id, b.value_date, b.reference_no, b.amount, b.narration
FROM bank_statement b
LEFT JOIN ledger l ON l.reference_no = b.reference_no
WHERE l.entry_id IS NULL
ORDER BY b.amount DESC;

-- 3b. Count and total of those bank items
SELECT COUNT(*) AS unrecorded_bank_items,
       ROUND(SUM(b.amount), 2) AS unrecorded_total
FROM bank_statement b
LEFT JOIN ledger l ON l.reference_no = b.reference_no
WHERE l.entry_id IS NULL;

-- 4. Same invoice in both, but the amounts are different
-- The subquery lists each ledger invoice once so duplicates don't show up twice.
SELECT l.reference_no,
       l.amount AS ledger_amt,
       b.amount AS bank_amt,
       ROUND(b.amount - l.amount, 2) AS difference
FROM (SELECT DISTINCT reference_no, amount FROM ledger) l
JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE ROUND(b.amount - l.amount, 2) <> 0
ORDER BY ABS(b.amount - l.amount) DESC;

-- 4b. Net difference (with + and - signs) and total size of the errors (ABS ignores the sign)
SELECT COUNT(*) AS mismatched_invoices,
       ROUND(SUM(b.amount - l.amount), 2) AS net_difference,
       ROUND(SUM(ABS(b.amount - l.amount)), 2) AS total_error_size
FROM (SELECT DISTINCT reference_no, amount FROM ledger) l
JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE ROUND(b.amount - l.amount, 2) <> 0;

-- 5. Invoices posted more than once in the ledger
-- GROUP BY groups rows by invoice number, HAVING keeps only groups with more than 1 row.
SELECT reference_no,
       COUNT(*) AS times_posted,
       SUM(amount) AS total_booked
FROM ledger
GROUP BY reference_no
HAVING COUNT(*) > 1
ORDER BY total_booked DESC;

-- 5b. How much the duplicates overstate the ledger (total posted minus one copy)
SELECT COUNT(*) AS duplicated_invoices,
       ROUND(SUM(extra_amount), 2) AS ledger_overstated_by
FROM (
    SELECT reference_no,
           SUM(amount) - MIN(amount) AS extra_amount
    FROM ledger
    GROUP BY reference_no
    HAVING COUNT(*) > 1
);

-- 6. Invoices paid more than 7 days after they were booked
-- julianday() turns a date into a number so I can subtract two dates (SQLite only).
SELECT l.reference_no, l.entry_date, b.value_date,
       CAST(julianday(b.value_date) - julianday(l.entry_date) AS INTEGER) AS days_to_clear
FROM (SELECT DISTINCT reference_no, entry_date FROM ledger) l
JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE julianday(b.value_date) - julianday(l.entry_date) > 7
ORDER BY days_to_clear DESC;

-- 7. Summary of the four exceptions that change the totals
SELECT 'Unpaid invoices (in ledger, not in bank)' AS exception_type,
       COUNT(*) AS items,
       ROUND(SUM(l.amount), 2) AS amount
FROM ledger l
LEFT JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE b.bank_txn_id IS NULL

UNION ALL

SELECT 'Unrecorded bank charges (in bank, not in ledger)',
       COUNT(*),
       ROUND(SUM(b.amount), 2)
FROM bank_statement b
LEFT JOIN ledger l ON l.reference_no = b.reference_no
WHERE l.entry_id IS NULL

UNION ALL

SELECT 'Amount mismatches (net difference)',
       COUNT(*),
       ROUND(SUM(b.amount - l.amount), 2)
FROM (SELECT DISTINCT reference_no, amount FROM ledger) l
JOIN bank_statement b ON b.reference_no = l.reference_no
WHERE ROUND(b.amount - l.amount, 2) <> 0

UNION ALL

SELECT 'Duplicate postings (ledger overstated by)',
       COUNT(*),
       ROUND(SUM(extra_amount), 2)
FROM (
    SELECT SUM(amount) - MIN(amount) AS extra_amount
    FROM ledger
    GROUP BY reference_no
    HAVING COUNT(*) > 1
);
