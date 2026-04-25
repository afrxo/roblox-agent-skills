--!strict
--!nolint LocalShadow

-- Spring survives target changes mid-flight (best for hover, drag).
-- Tween restarts on every source change (best for fixed-duration transitions).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent
local peek = Fusion.peek
local scoped = Fusion.scoped

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

local scope = scoped(Fusion)

local hovered = scope:Value(false)
local selected = scope:Value(false)

-- Spring(source, speed, damping) — damping 1 = critical, <1 = overshoot, >1 = sluggish.
local hoverScale = scope:Spring(
    scope:Computed(function(use, _) return if use(hovered) then 1.05 else 1 end),
    25, 1
)

local TWEEN_FAST = TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local backgroundColor = scope:Tween(
    scope:Computed(function(use, _)
        if use(selected) then
            return Color3.fromRGB(0, 120, 255)
        elseif use(hovered) then
            return Color3.fromRGB(60, 60, 70)
        else
            return Color3.fromRGB(40, 40, 48)
        end
    end),
    TWEEN_FAST
)

scope:New "ScreenGui" {
    Name = "AnimDemo",
    Parent = playerGui,
    ResetOnSpawn = false,

    [Children] = scope:New "Frame" {
        Size = UDim2.fromScale(0.18, 0.25),
        Position = UDim2.fromScale(0.5, 0.5),
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,

        [Children] = {
            scope:New "UIAspectRatioConstraint" {
                AspectRatio = 1,
                AspectType = Enum.AspectType.FitWithinMaxSize,
                DominantAxis = Enum.DominantAxis.Width,
            },

            scope:New "TextButton" {
                Size = scope:Computed(function(use, _)
                    local s = use(hoverScale)
                    return UDim2.fromScale(s, s)
                end),
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.5),
                BackgroundColor3 = backgroundColor,
                AutoButtonColor = false,
                Font = Enum.Font.GothamBold,
                TextColor3 = Color3.new(1, 1, 1),
                TextScaled = true,
                Text = scope:Computed(function(use, _)
                    return if use(selected) then "Selected ✓" else "Click me"
                end),

                [Children] = {
                    scope:New "UICorner" { CornerRadius = UDim.new(0.08, 0) },
                    scope:New "UIPadding" {
                        PaddingTop = UDim.new(0.3, 0),
                        PaddingBottom = UDim.new(0.3, 0),
                        PaddingLeft = UDim.new(0.15, 0),
                        PaddingRight = UDim.new(0.15, 0),
                    },
                    scope:New "UITextSizeConstraint" { MaxTextSize = 24 },
                    scope:New "UIStroke" {
                        StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                        Thickness = 0.08,
                        Color = Color3.new(),
                        Transparency = scope:Tween(
                            scope:Computed(function(use, _)
                                return if use(hovered) or use(selected) then 0.3 else 1
                            end),
                            TWEEN_FAST
                        ),
                    },
                },

                [OnEvent "MouseEnter"] = function() hovered:set(true) end,
                [OnEvent "MouseLeave"] = function() hovered:set(false) end,
                [OnEvent "Activated"] = function() selected:set(not peek(selected)) end,
            },
        },
    },
}

-- Tween/Spring animate number/Vector2/Vector3/UDim/UDim2/Color3/CFrame only.
-- For booleans/strings/tables, derive a number in a Computed first.
