--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Children = Fusion.Children
local OnEvent = Fusion.OnEvent

type UsedAs<T> = Fusion.UsedAs<T>

export type ButtonProps = {
    Text: UsedAs<string>,
    OnClick: () -> ()?,
    Size: UsedAs<UDim2>?,
    Position: UsedAs<UDim2>?,
    AnchorPoint: UsedAs<Vector2>?,
    LayoutOrder: UsedAs<number>?,
    BackgroundColor3: UsedAs<Color3>?,
    Disabled: UsedAs<boolean>?,
}

local function Button(scope: Fusion.Scope, props: ButtonProps): TextButton
    return scope:New "TextButton" {
        Size = props.Size or UDim2.fromScale(0.25, 0.08),
        Position = props.Position,
        AnchorPoint = props.AnchorPoint,
        LayoutOrder = props.LayoutOrder,

        BackgroundColor3 = props.BackgroundColor3 or Color3.fromRGB(0, 120, 255),
        AutoButtonColor = true,
        Active = scope:Computed(function(use, _)
            return not (use(props.Disabled or false))
        end),

        Font = Enum.Font.GothamBold,
        Text = props.Text,
        TextColor3 = Color3.new(1, 1, 1),
        TextScaled = true,

        [Children] = {
            scope:New "UICorner" { CornerRadius = UDim.new(0.2, 0) },
            scope:New "UIPadding" {
                PaddingLeft = UDim.new(0.08, 0),
                PaddingRight = UDim.new(0.08, 0),
            },
            scope:New "UITextSizeConstraint" { MaxTextSize = 20 },
            scope:New "UIStroke" {
                StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize,
                Thickness = 0.05,
                Color = Color3.new(),
                Transparency = 0.7,
            },
        },

        [OnEvent "Activated"] = function()
            if props.OnClick and not (Fusion.peek(props.Disabled or false)) then
                props.OnClick()
            end
        end,
    }
end

return Button
