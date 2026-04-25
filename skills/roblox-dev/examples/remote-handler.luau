--!strict

-- Server-side RemoteEvent handler with validated boundary, per-player rate limit,
-- and idempotent application.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PurchaseItem = ReplicatedStorage:WaitForChild("PurchaseItem") :: RemoteEvent

type ItemId = "sword" | "shield" | "potion"

local PRICES: { [ItemId]: number } = {
    sword = 100,
    shield = 75,
    potion = 25,
}

local function isItemId(v: unknown): boolean
    return v == "sword" or v == "shield" or v == "potion"
end

-- Per-player rate limit: max 5 purchases per 10 seconds, dropped after.
local rate: { [Player]: { count: number, windowStart: number } } = {}
local WINDOW = 10
local MAX_PER_WINDOW = 5

local function allow(player: Player): boolean
    local now = os.clock()
    local r = rate[player]
    if r == nil or now - r.windowStart > WINDOW then
        rate[player] = { count = 1, windowStart = now }
        return true
    end
    if r.count >= MAX_PER_WINDOW then
        return false
    end
    r.count += 1
    return true
end

Players.PlayerRemoving:Connect(function(player) rate[player] = nil end)

-- Game-state would live in a dedicated module; this example uses an inline table.
local inventories: { [Player]: { [ItemId]: number } } = {}
Players.PlayerAdded:Connect(function(player) inventories[player] = {} end)
Players.PlayerRemoving:Connect(function(player) inventories[player] = nil end)

local function applyPurchase(player: Player, itemId: ItemId, qty: number)
    -- Currency check, deduction, ledger writes would go here.
    local inv = inventories[player]
    if inv == nil then return end
    inv[itemId] = (inv[itemId] or 0) + qty
end

PurchaseItem.OnServerEvent:Connect(function(player, itemId: unknown, qty: unknown)
    -- Validate every boundary parameter.
    if not isItemId(itemId) then return end
    if typeof(qty) ~= "number" or qty ~= qty or qty < 1 or qty > 99 then return end
    -- Rate limit after validation so spammers don't even count.
    if not allow(player) then return end

    applyPurchase(player, itemId :: ItemId, qty)
end)
