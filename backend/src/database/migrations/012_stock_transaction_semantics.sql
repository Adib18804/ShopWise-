-- Temporarily permit the new values before transforming legacy rows.
ALTER TABLE stock_transactions
MODIFY transaction_type ENUM(
  'PURCHASE', 'SALE', 'ADJUSTMENT', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT',
  'RETURN', 'EXPIRED', 'DAMAGED'
) NOT NULL;

-- Preserve legacy adjustment direction and switch to explicit positive quantities.
UPDATE stock_transactions
SET transaction_type = CASE WHEN quantity < 0 THEN 'ADJUSTMENT_OUT' ELSE 'ADJUSTMENT_IN' END,
    quantity = ABS(quantity)
WHERE transaction_type = 'ADJUSTMENT';

UPDATE stock_transactions SET quantity = ABS(quantity) WHERE quantity < 0;

ALTER TABLE stock_transactions
MODIFY transaction_type ENUM(
  'PURCHASE', 'SALE', 'ADJUSTMENT_IN', 'ADJUSTMENT_OUT', 'RETURN', 'EXPIRED', 'DAMAGED'
) NOT NULL;
