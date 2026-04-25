--!strict

-- Trust-boundary validation. The exploiter can send anything, so each parameter
-- comes in as `unknown` and gets narrowed. Typing as `number`/`string` directly
-- would let the type checker accept invalid runtime input.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PurchaseItem: RemoteEvent = Remotes:WaitForChild("PurchaseItem") :: RemoteEvent

type ItemId = "sword" | "shield" | "potion"

local PRICES: { [ItemId]: number } = {
    sword = 100,
    shield = 75,
    potion = 25,
}

local function isItemId(v: unknown): boolean
    return v == "sword" or v == "shield" or v == "potion"
end

local function purchase(player: Player, itemId: ItemId, quantity: number)
    -- Deduct currency, grant item, ...
    print(`{player.Name} bought {quantity}x {itemId} for {PRICES[itemId] * quantity}`)
end

PurchaseItem.OnServerEvent:Connect(function(player, itemId: unknown, quantity: unknown)
    if not isItemId(itemId) then
        return
    end
    if typeof(quantity) ~= "number" or quantity ~= quantity or quantity < 1 or quantity > 99 then
        -- second check rejects NaN; bounds reject negative / huge values
        return
    end

    -- itemId narrowed to ItemId via the predicate; quantity narrowed to number.
    purchase(player, itemId :: ItemId, quantity)
end)
