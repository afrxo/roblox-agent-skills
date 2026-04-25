--!strict
--!nolint LocalShadow

-- For large lists with stable identity, use ForValues / ForKeys / ForPairs
-- instead of a Computed — the Computed re-creates every row on any change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

type Todo = { id: number, text: string, done: boolean }

local scope = scoped(Fusion)

local todos: Fusion.Value<{ Todo }> = scope:Value({
    { id = 1, text = "Write Fusion skill", done = true },
    { id = 2, text = "Write Vide skill", done = false },
    { id = 3, text = "Write React Lua skill", done = false },
})

local nextId = 4

local function toggle(id: number)
    local list = peek(todos)
    local copy = table.clone(list)
    for i, todo in copy do
        if todo.id == id then
            copy[i] = { id = todo.id, text = todo.text, done = not todo.done }
            break
        end
    end
    todos:set(copy)
end

local function add()
    local list = peek(todos)
    local copy = table.clone(list)
    table.insert(copy, { id = nextId, text = `Task {nextId}`, done = false })
    nextId += 1
    todos:set(copy)
end

scope:New "ScreenGui" {
    Name = "TodoDemo",
    Parent = playerGui,
    ResetOnSpawn = false,

    [Children] = scope:New "Frame" {
        Size = UDim2.fromScale(0.28, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(28, 28, 32),

        [Children] = {
            scope:New "UIAspectRatioConstraint" {
                AspectRatio = 0.7,
                AspectType = Enum.AspectType.FitWithinMaxSize,
                DominantAxis = Enum.DominantAxis.Height,
            },
            scope:New "UICorner" { CornerRadius = UDim.new(0.04, 0) },
            scope:New "UIPadding" {
                PaddingTop = UDim.new(0.03, 0),
                PaddingBottom = UDim.new(0.03, 0),
                PaddingLeft = UDim.new(0.04, 0),
                PaddingRight = UDim.new(0.04, 0),
            },
            scope:New "UIListLayout" {
                Padding = UDim.new(0.012, 0),
                SortOrder = Enum.SortOrder.LayoutOrder,
            },

            scope:New "TextButton" {
                LayoutOrder = 0,
                Size = UDim2.fromScale(1, 0.08),
                BackgroundColor3 = Color3.fromRGB(0, 180, 0),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = "+ Add task",
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 16 },
                },
                [OnEvent "Activated"] = add,
            },

            scope:Computed(function(use, scope)
                local rows: { Instance } = {}
                for i, todo in use(todos) do
                    rows[i] = scope:New "TextButton" {
                        LayoutOrder = i,
                        Size = UDim2.fromScale(1, 0.06),
                        BackgroundColor3 = if todo.done
                            then Color3.fromRGB(40, 80, 40)
                            else Color3.fromRGB(50, 50, 56),
                        Font = Enum.Font.Gotham,
                        TextColor3 = Color3.new(1, 1, 1),
                        TextScaled = true,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        Text = `{if todo.done then "[x]" else "[ ]"}  {todo.text}`,
                        [Children] = {
                            scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                            scope:New "UIPadding" {
                                PaddingLeft = UDim.new(0.04, 0),
                                PaddingRight = UDim.new(0.04, 0),
                            },
                            scope:New "UITextSizeConstraint" { MaxTextSize = 14 },
                        },
                        [OnEvent "Activated"] = function() toggle(todo.id) end,
                    }
                end
                return rows
            end),
        },
    },
}
