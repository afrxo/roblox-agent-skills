--!strict
--!nolint LocalShadow

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local doCleanup = Fusion.doCleanup
local peek = Fusion.peek
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local scope = scoped(Fusion)

local count = scope:Value(0)
local doubled = scope:Computed(function(use, _)
    return use(count) * 2
end)

scope:Observer(count):onChange(function()
    print(`count changed to {peek(count)}`)
end)

scope:New "ScreenGui" {
    Name = "CounterDemo",
    Parent = playerGui,
    ResetOnSpawn = false,

    [Children] = scope:New "Frame" {
        Size = UDim2.fromScale(0.22, 0.22),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(28, 28, 32),

        [Children] = {
            scope:New "UIAspectRatioConstraint" {
                AspectRatio = 1.5,
                AspectType = Enum.AspectType.FitWithinMaxSize,
                DominantAxis = Enum.DominantAxis.Width,
            },
            scope:New "UICorner" { CornerRadius = UDim.new(0.06, 0) },
            scope:New "UIPadding" {
                PaddingTop = UDim.new(0.08, 0),
                PaddingBottom = UDim.new(0.08, 0),
                PaddingLeft = UDim.new(0.08, 0),
                PaddingRight = UDim.new(0.08, 0),
            },
            scope:New "UIListLayout" {
                Padding = UDim.new(0.05, 0),
                SortOrder = Enum.SortOrder.LayoutOrder,
                HorizontalAlignment = Enum.HorizontalAlignment.Center,
            },

            scope:New "TextLabel" {
                LayoutOrder = 1,
                Size = UDim2.fromScale(1, 0.2),
                BackgroundTransparency = 1,
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = scope:Computed(function(use, _)
                    return `count = {use(count)}    doubled = {use(doubled)}`
                end),
                [Children] = scope:New "UITextSizeConstraint" { MaxTextSize = 22 },
            },

            scope:New "TextButton" {
                LayoutOrder = 2,
                Size = UDim2.fromScale(1, 0.3),
                BackgroundColor3 = Color3.fromRGB(0, 120, 255),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = "Increment",
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 20 },
                },
                [OnEvent "Activated"] = function() count:set(peek(count) + 1) end,
            },

            scope:New "TextButton" {
                LayoutOrder = 3,
                Size = UDim2.fromScale(1, 0.3),
                BackgroundColor3 = Color3.fromRGB(120, 120, 120),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = "Reset",
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 20 },
                },
                [OnEvent "Activated"] = function() count:set(0) end,
            },
        },
    },
}

player.AncestryChanged:Connect(function(_, parent)
    if parent == nil then doCleanup(scope) end
end)
