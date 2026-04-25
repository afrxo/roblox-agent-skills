--!strict

-- String enums + exhaustiveMatch helper.
-- Compile-time guarantee that every variant is handled.

export type Element = "fire" | "water" | "grass" | "electric"

local function exhaustiveMatch(value: never): never
    error(`Unknown value in exhaustive match: {value}`)
end

local function effectiveAgainst(attacker: Element, defender: Element): number
    if attacker == "fire" then
        return if defender == "grass" then 2 else 1
    elseif attacker == "water" then
        return if defender == "fire" then 2 else 1
    elseif attacker == "grass" then
        return if defender == "water" then 2 else 1
    elseif attacker == "electric" then
        return if defender == "water" then 2 else 1
    else
        -- If a new variant is added to Element and a branch is missing,
        -- this line becomes a static type error: Element is not subtype of never.
        return exhaustiveMatch(attacker)
    end
end

return effectiveAgainst
