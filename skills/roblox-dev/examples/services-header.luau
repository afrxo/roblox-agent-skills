--!strict

-- The standard top-of-file shape for any server or client script.
-- GetService calls alphabetical, then `local` aliases for non-service modules,
-- then exported types, then implementation. No GetService scattered later.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Inventory = require(ReplicatedStorage.Shared.Inventory)
local Logger = require(ReplicatedStorage.Shared.Logger)

export type SpawnInfo = {
    player: Player,
    position: Vector3,
}

local function onPlayerAdded(player: Player)
    Logger.info(`{player.Name} joined`)
    Inventory.init(player)
end

local function spawnAt(info: SpawnInfo)
    local character = info.player.Character
    if character == nil then return end
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
    if root == nil then return end
    root.CFrame = CFrame.new(info.position)
end

if RunService:IsServer() then
    for _, player in Players:GetPlayers() do onPlayerAdded(player) end
    Players.PlayerAdded:Connect(onPlayerAdded)
end

return {
    spawnAt = spawnAt,
}
