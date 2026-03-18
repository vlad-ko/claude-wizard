# Common Patterns & Anti-Patterns

Quick reference for the wizard skill.

## Concurrency Patterns

### TOCTOU Prevention (Time-of-Check to Time-of-Use)

```
// WRONG: Race condition between check and update
status = read(record)           // Time of Check
// ... another process modifies record here ...
if status == "pending":         // Time of Use (STALE!)
    update(record, "processing")

// CORRECT: Atomic check-and-act with locking
lock(record)
status = read(record)           // Read under lock
if status == "pending":
    update(record, "processing")
unlock(record)
```

### Atomic State Transitions

```
// CORRECT: Single atomic operation
affected = UPDATE records
    SET status = 'processing', started_at = now()
    WHERE id = ? AND status = 'pending'

if affected > 0:
    // Success - proceed
else:
    // State already changed - handle appropriately
```

## Test Patterns

### Mutation-Resistant Assertions

```
// WEAK: Just checks success
assert result == true

// STRONG: Checks specific values that would catch mutations
assert result.count == 5
assert result.status == "completed"
assert result.completed_at != null
assert result.items[0].name == "expected"
```

### Boundary Testing

```
// If code checks `value > 0`, test:
test_with_value(0)   // boundary
test_with_value(1)   // just above
test_with_value(-1)  // just below

// If code checks string length:
test_with_empty_string("")
test_with_single_char("a")
test_with_max_length("a" * MAX)
test_with_over_max("a" * (MAX + 1))
```

## Implementation Patterns

### Constants Over Magic Values

```
// WRONG: Hard-coded strings scattered across codebase
status = "active"
type = "traditional_ira"

// CORRECT: Centralized constants
status = Status.ACTIVE
type = AccountType.TRADITIONAL_IRA
```

### Error Handling in Transactions

```
// BUG: Audit record is rolled back with the transaction
begin_transaction()
    create_audit_event("operation_failed")  // rolled back!
    update(record, status: "blocked")       // rolled back!
    raise Error("something went wrong")     // triggers rollback
end_transaction()

// CORRECT: Error state persists outside the transaction
try:
    begin_transaction()
        do_work()
    end_transaction()
catch Error as e:
    create_audit_event("operation_failed")  // persists
    update(record, status: "blocked")       // persists
    raise e
```

### Duplication Over the Wrong Abstraction

```
// When fixing a bug in one place, check whether the same pattern exists elsewhere:
grep -rn "the_pattern" src/

// Default to duplicating the fix in each location.
// Only extract a shared abstraction when ALL of these are true:
//   1. The same logic appears three or more times
//   2. The caller contexts are genuinely similar (not just superficially alike)
//   3. You have been explicitly asked to extract, OR the duplication is exact
//
// The wrong abstraction is more expensive than duplication.
// When in doubt, leave the duplication.
```

## Verification Commands

```bash
# Check if a function/method exists before using it
grep -r "function methodName" src/

# Find all usages of a pattern
grep -rn "pattern" src/

# Check for existing constants before hard-coding
grep -rn "CONSTANT_NAME" src/

# Review what you're about to commit
git diff --staged
```

## Pre-Implementation Verification

Before writing ANY code, answer:

1. What are ALL the ways this code can be reached?
2. What other code modifies the same data?
3. What happens under concurrent access?
4. What are the edge cases? (null, zero, negative, max, empty, duplicate)
5. What invariants must this code maintain?
6. How would I test that those invariants hold?

If you can't answer these, you're not ready to write code yet.
