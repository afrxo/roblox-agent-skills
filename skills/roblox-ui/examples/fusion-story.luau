--!strict
-- UI Labs story for a Fusion 0.3 Button component.
-- File should be named `Button.story.luau` so UI Labs auto-discovers it.
-- Place a sibling `*.storybook` ModuleScript with `storyRoots = { script.Parent }`
-- to group related stories under one storybook entry.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Button = require(ReplicatedStorage.Shared.UI.Button)

return {
    fusion = Fusion,

    -- Each entry becomes a `Fusion.Value` on `props.controls`. The default value
    -- determines control type: boolean → toggle, string → text input,
    -- Color3 → color picker, number → slider, etc.
    controls = {
        Label = "Click me",
        Disabled = false,
        BackgroundColor3 = Color3.fromRGB(0, 120, 255),
    },

    story = function(props: {
        target: Frame,
        controls: {
            Label: Fusion.Value<string>,
            Disabled: Fusion.Value<boolean>,
            BackgroundColor3: Fusion.Value<Color3>,
        },
        scope: Fusion.Scope<typeof(Fusion)>,
    })
        -- Mount component under props.target. props.scope is auto-cleaned on
        -- unmount/reload — no cleanup return needed.
        local button = Button(props.scope, {
            Text = props.controls.Label,
            Disabled = props.controls.Disabled,
            BackgroundColor3 = props.controls.BackgroundColor3,
            Size = UDim2.fromOffset(180, 56),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            OnClick = function()
                print("clicked")
            end,
        })
        button.Parent = props.target
    end,
}
