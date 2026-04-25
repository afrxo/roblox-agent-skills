--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local Out = Fusion.Out
local peek = Fusion.peek
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local scope = scoped(Fusion)

local username = scope:Value("")
local message = scope:Value("")
local status = scope:Value("")

local function submit()
    local u = peek(username)
    local m = peek(message)
    if u == "" or m == "" then
        status:set("Both fields required")
        return
    end
    status:set(`Sending "{m}" as {u}...`)
end

-- Fusion 0.3 has no [Ref] — capture the Instance by storing scope:New's return.
local usernameBox: TextBox = scope:New "TextBox" {
    LayoutOrder = 1,
    Size = UDim2.fromScale(1, 0.18),
    BackgroundColor3 = Color3.fromRGB(50, 50, 56),
    Font = Enum.Font.Gotham,
    TextColor3 = Color3.new(1, 1, 1),
    TextScaled = true,
    PlaceholderText = "Username",
    ClearTextOnFocus = false,
    [Children] = {
        scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
        scope:New "UITextSizeConstraint" { MaxTextSize = 16 },
    },
    [Out "Text"] = username,
}

scope:New "ScreenGui" {
    Name = "FormDemo",
    Parent = playerGui,
    ResetOnSpawn = false,

    [Children] = scope:New "Frame" {
        Size = UDim2.fromScale(0.3, 0.32),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.fromRGB(28, 28, 32),

        [Children] = {
            scope:New "UIAspectRatioConstraint" {
                AspectRatio = 1.4,
                AspectType = Enum.AspectType.FitWithinMaxSize,
                DominantAxis = Enum.DominantAxis.Width,
            },
            scope:New "UICorner" { CornerRadius = UDim.new(0.04, 0) },
            scope:New "UIPadding" {
                PaddingTop = UDim.new(0.06, 0),
                PaddingBottom = UDim.new(0.06, 0),
                PaddingLeft = UDim.new(0.06, 0),
                PaddingRight = UDim.new(0.06, 0),
            },
            scope:New "UIListLayout" {
                Padding = UDim.new(0.03, 0),
                SortOrder = Enum.SortOrder.LayoutOrder,
            },

            usernameBox,

            scope:New "TextBox" {
                LayoutOrder = 2,
                Size = UDim2.fromScale(1, 0.18),
                BackgroundColor3 = Color3.fromRGB(50, 50, 56),
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                PlaceholderText = "Message",
                ClearTextOnFocus = false,
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 16 },
                },
                [Out "Text"] = message,
            },

            scope:New "TextButton" {
                LayoutOrder = 3,
                Size = UDim2.fromScale(1, 0.18),
                BackgroundColor3 = Color3.fromRGB(0, 120, 255),
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = "Submit",
                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 18 },
                },
                [OnEvent "Activated"] = submit,
            },

            scope:New "TextLabel" {
                LayoutOrder = 4,
                Size = UDim2.fromScale(1, 0.12),
                BackgroundTransparency = 1,
                Font = Enum.Font.Gotham,
                TextColor3 = Color3.fromRGB(180, 180, 180),
                TextScaled = true,
                Text = status,
                [Children] = scope:New "UITextSizeConstraint" { MaxTextSize = 13 },
            },
        },
    },
}

usernameBox:CaptureFocus()
