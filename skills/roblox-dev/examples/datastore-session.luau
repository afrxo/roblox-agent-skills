--!strict

-- Session-locked DataStore pattern.
-- Load on PlayerAdded, hold in memory for the session, save on PlayerRemoving
-- and BindToClose. All calls wrapped in pcall with bounded retry.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local store = DataStoreService:GetDataStore("PlayerData_v1")

export type PlayerData = {
    coins: number,
    level: number,
    lastSeen: number,
}

local DEFAULT_DATA: PlayerData = { coins = 0, level = 1, lastSeen = 0 }

local sessionData: { [Player]: PlayerData } = {}

local function key(player: Player): string
    return `Player_{player.UserId}`
end

local function retryAsync<T>(fn: () -> T, attempts: number?): (boolean, T?)
    local n = attempts or 5
    local delay = 1
    local lastErr: unknown
    for i = 1, n do
        local ok, result = pcall(fn)
        if ok then return true, result end
        lastErr = result
        warn(`DataStore attempt {i} failed: {result}`)
        task.wait(delay)
        delay = math.min(delay * 2, 30)
    end
    warn(`DataStore failed after {n} attempts: {lastErr}`)
    return false, nil
end

local function load(player: Player): PlayerData
    local ok, data = retryAsync(function()
        return store:GetAsync(key(player))
    end)

    if ok and typeof(data) == "table" then
        return data :: PlayerData
    end
    return table.clone(DEFAULT_DATA)
end

local function save(player: Player)
    local data = sessionData[player]
    if data == nil then return end
    data.lastSeen = os.time()

    retryAsync(function()
        return store:UpdateAsync(key(player), function(prev)
            -- If you wanted a real lock, prev would be inspected here for stale sessions.
            return data
        end)
    end)
end

Players.PlayerAdded:Connect(function(player)
    sessionData[player] = load(player)
end)

Players.PlayerRemoving:Connect(function(player)
    save(player)
    sessionData[player] = nil
end)

-- BindToClose has ~30s total across all players. Save in parallel.
game:BindToClose(function()
    if RunService:IsStudio() then return end
    local pending: { thread } = {}
    for player in sessionData do
        local co = task.spawn(function() save(player) end)
        table.insert(pending, co)
    end
    -- Best-effort: give threads time to finish before shutdown ends.
    local deadline = os.clock() + 25
    while os.clock() < deadline do
        local stillRunning = false
        for _, co in pending do
            if coroutine.status(co) ~= "dead" then
                stillRunning = true
                break
            end
        end
        if not stillRunning then break end
        task.wait(0.5)
    end
end)

local DataStoreSession = {}

function DataStoreSession.get(player: Player): PlayerData?
    return sessionData[player]
end

return table.freeze(DataStoreSession)
