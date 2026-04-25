# Typed Class Recipe

For the rare case you genuinely need a metatable-backed class. Default to plain data + free functions (see SKILL.md).

The key problem: without annotations, Luau infers a *different* `self` type per method, breaking cross-method field access. Annotate `self` explicitly.

```luau
--!strict

-- 1. Public data shape (exported)
export type Account = {
    name: string,
    balance: number,
}

-- 2. Full class type (private — includes __index and constructor)
type AccountImpl = Account & {
    __index: AccountImpl,
    new: (name: string, balance: number) -> Account,
    deposit: (self: Account, amount: number) -> (),
    withdraw: (self: Account, amount: number) -> boolean,
    getBalance: (self: Account) -> number,
}

-- 3. Implement
local Account: AccountImpl = {} :: AccountImpl
Account.__index = Account

function Account.new(name: string, balance: number): Account
    return setmetatable({ name = name, balance = balance }, Account) :: Account
end

function Account:deposit(amount: number): ()
    self.balance += amount
end

function Account:withdraw(amount: number): boolean
    if self.balance < amount then return false end
    self.balance -= amount
    return true
end

function Account:getBalance(): number
    return self.balance
end

return table.freeze(Account)
```

**Notes:**

- `setmetatable(...)` must be cast with `:: Account` — the type checker cannot infer through metatables without help
- `table.freeze` on the class table catches accidental mutations at runtime
- `:deposit(...)` on an instance works even though the method is defined as `Account.deposit` — `:` and `.` are equivalent at the call site

**Upcoming:** Luau plans to share `self` types automatically for `:` definitions (RFC in progress). When implemented, explicit `self: T` annotations on methods won't be needed.
