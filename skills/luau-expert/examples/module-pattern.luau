--!strict

-- Clean module skeleton.
-- Imports alphabetical, named module return, frozen, exported types up top.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(ReplicatedStorage.Shared.Logger)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Connection = {
    id: string,
    openedAt: number,
}

export type Config = {
    timeout: number,
    retries: number,
}

const DEFAULT_CONFIG: Config = {
    timeout = 30,
    retries = 3,
}

local activeConnections: { [string]: Connection? } = {}
local onConnectionOpened = Signal.new()

local Connections = {}

function Connections.open(id: string, cfg: Config?): Connection
    local c = cfg or DEFAULT_CONFIG
    local conn: Connection = { id = id, openedAt = os.clock() }
    activeConnections[id] = conn
    Logger.info(`Opened {id} (timeout={c.timeout})`)
    onConnectionOpened:Fire(conn)
    return conn
end

function Connections.close(id: string): boolean
    if activeConnections[id] == nil then
        return false
    end
    activeConnections[id] = nil
    return true
end

function Connections.get(id: string): Connection?
    return activeConnections[id]
end

Connections.opened = onConnectionOpened

return table.freeze(Connections)
