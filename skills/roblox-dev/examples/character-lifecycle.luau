--!strict

-- Per-character setup with proper cleanup across respawns.
-- Each new character gets fresh connections; old connections are disconnected
-- before the next character spawns.

local Players = game:GetService("Players")

local perCharacterConnections: { [Player]: { RBXScriptConnection } } = {}

local function disconnectAll(player: Player)
    local list = perCharacterConnections[player]
    if list == nil then return end
    for _, conn in list do conn:Disconnect() end
    perCharacterConnections[player] = nil
end

local function onCharacterAdded(player: Player, character: Model)
    -- Clear previous character's connections before binding new ones.
    disconnectAll(player)
    perCharacterConnections[player] = {}

    local conns = perCharacterConnections[player] :: { RBXScriptConnection }

    local humanoid = character:WaitForChild("Humanoid", 5) :: Humanoid?
    if humanoid == nil then return end

    table.insert(conns, humanoid.Died:Connect(function()
        print(`{player.Name} died`)
    end))

    table.insert(conns, humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
        print(`{player.Name} walkspeed = {humanoid.WalkSpeed}`)
    end))
end

local function onPlayerAdded(player: Player)
    if player.Character ~= nil then
        onCharacterAdded(player, player.Character)
    end
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)
end

local function onPlayerRemoving(player: Player)
    disconnectAll(player)
end

-- Handle players already in the server when this script started, then future joins.
for _, player in Players:GetPlayers() do onPlayerAdded(player) end
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
