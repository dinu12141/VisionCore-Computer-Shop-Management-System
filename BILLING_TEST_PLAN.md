# Billing & Customer Module - Test Plan

## 1. Customer Management Scenarios

| Feature       | Scenario                                 | Expected Result                                                                   |
| ------------- | ---------------------------------------- | --------------------------------------------------------------------------------- |
| **Add**       | Create a customer with mandatory fields  | Record saved, `CUS-XXXXXX` code generated, UI notifies success.                   |
| **Duplicate** | Create a customer with same Name + Phone | System shows "Duplicate Found" dialog; user can opt to use existing or force new. |
| **Search**    | Search by Phone number fragment          | Table filters instantly to matching records.                                      |
| **Category**  | Filter by "Government" chip              | Only customers assigned to the Government category are displayed.                 |
| **Edit**      | Change customer address                  | record updates in DB; list reflects new address immediately.                      |

## 2. Invoicing & Billing Scenarios

| Feature      | Scenario                             | Expected Result                                                            |
| ------------ | ------------------------------------ | -------------------------------------------------------------------------- |
| **Standard** | Billing an existing customer         | Items added, totals calculated, snapshot stored, print preview opens.      |
| **Walk-in**  | Proceed without selecting a customer | Walk-in fields (Name/Phone) appear; Snapshot saved with `code: 'WALK-IN'`. |
| **Drafting** | Save as "Draft"                      | Invoice saved with `status: 'draft'`, can be edited/issued later.          |
| **Items**    | Add 10+ items to one invoice         | Scrollable list works, table maintains height, totals sum correctly.       |

## 3. Calculation Logic (The "Math" Check)

- [ ] **Line Total**: `(Qty * Unit Price) - Discount` per row.
- [ ] **Subtotal**: Sum of all line totals.
- [ ] **Grand Total**: `Subtotal - Global Discount`.
- [ ] **Balance**: `Grand Total - Paid Amount`.
- [ ] **Edge Case**: Set 100% discount. (Total should be 0.00, not negative).
- [ ] **Edge Case**: Enter non-numeric values in price. (UI should block/sanitize).

## 4. Printing & PDF Fidelity

- [ ] **Logo/Branding**: "V" Logo and red "INVOICE" header must align exactly with reference.
- [ ] **Zebra Striping**: Alternating grey/white rows for readability.
- [ ] **Overflow**: Longer descriptions should truncate or wrap without breaking table layout.
- [ ] **Fixed Height**: Footer and Totals remained at the bottom regardless of item count (via CSS filler rows).

## 5. Automated Test Hooks (Cypress/Vitest)

For automated testing, we use the following `data-testid` attributes:

- `data-testid="customer-search"`
- `data-testid="billing-submit"`
- `data-testid="line-total-X"` (where X is index)

**Example Test Idea:**

```javascript
it('should calculate balance correctly when partial payment is made', () => {
  fillItem(0, { qty: 2, price: 1000 }) // Line total 2000
  setGlobalDiscount(200) // Total 1800
  setPaidAmount(1000) // Paid 1000
  expect(balance).to.equal(800)
})
```

## 6. Edge Cases & Error Handling

1. **Network Failure**: Submit invoice while offline (Should show error notify, keep draft state).
2. **Empty Invoice**: Submission of 0 items or null descriptions (Should block 'Issue' action).
3. **Session Expiry**: Proceeding with invoice when JWT expires (RLS policy should block, redirect to login).
4. **Rounding**: Ensure `NUMERIC(14,2)` in Postgres handles `0.33 + 0.33 + 0.34 = 1.00` correctly.
