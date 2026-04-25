--!strict

-- Disposable scope. Track connections + arbitrary cleanup callbacks; release
-- them all at once. Plain data + free functions — no metatables.

export type Tracker = {
    items: { RBXScriptConnection | () -> () },
    destroyed: boolean,
}

local function new(): Tracker
    return {
        items = {},
        destroyed = false,
    }
end

local function add(tracker: Tracker, conn: RBXScriptConnection): RBXScriptConnection
    assert(not tracker.destroyed, "Tracker already destroyed")
    table.insert(tracker.items, conn)
    return conn
end

local function addCleanup(tracker: Tracker, fn: () -> ())
    assert(not tracker.destroyed, "Tracker already destroyed")
    table.insert(tracker.items, fn)
end

local function destroy(tracker: Tracker)
    if tracker.destroyed then return end
    tracker.destroyed = true
    for _, item in tracker.items do
        if typeof(item) == "RBXScriptConnection" then
            item:Disconnect()
        else
            local ok, err = pcall(item :: () -> ())
            if not ok then warn(`Tracker cleanup error: {err}`) end
        end
    end
    table.clear(tracker.items)
end

local Tracker = {
    new = new,
    add = add,
    addCleanup = addCleanup,
    destroy = destroy,
}

return table.freeze(Tracker)

--[[
Usage:

local Tracker = require(script.Parent.connectionTracker)

local function setupDoor(door: Model)
    local t = Tracker.new()
    Tracker.add(t, door.AncestryChanged:Connect(function(_, parent)
        if parent == nil then Tracker.destroy(t) end
    end))
    Tracker.add(t, door:WaitForChild("ClickDetector").MouseClick:Connect(function(player)
        toggleDoor(door, player)
    end))
    Tracker.addCleanup(t, function() print("door cleaned up") end)
end
]]
