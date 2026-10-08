--[[
    Mozzy EMS Simulator - shared/utils.lua
    Small stateless helpers used by both sides.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Utils = {}

--- Pick a random float between min/max (inclusive), rounded to `decimals`
function MozzyEMS.Utils.RandomFloat(min, max, decimals)
    decimals = decimals or 0
    local mult = 10 ^ decimals
    return math.floor((min + (math.random() * (max - min))) * mult + 0.5) / mult
end

--- Pick a random integer in [min, max]
function MozzyEMS.Utils.RandomInt(min, max)
    if min == max then return min end
    return math.random(min, max)
end

--- Pick a random element from an array
function MozzyEMS.Utils.RandomElement(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(1, #tbl)]
end

--- Weighted random pick. items = { {value=..., weight=...}, ... }
function MozzyEMS.Utils.WeightedRandom(items)
    local total = 0
    for _, item in ipairs(items) do
        total = total + (item.weight or 1)
    end
    if total <= 0 then return nil end

    local roll = math.random() * total
    local cursor = 0
    for _, item in ipairs(items) do
        cursor = cursor + (item.weight or 1)
        if roll <= cursor then
            return item.value
        end
    end
    return items[#items].value
end

--- Clamp a number between min/max
function MozzyEMS.Utils.Clamp(value, min, max)
    if value < min then return min end
    if value > max then return max end
    return value
end

--- table.contains equivalent for arrays
function MozzyEMS.Utils.Contains(tbl, value)
    if not tbl then return false end
    for _, v in ipairs(tbl) do
        if v == value then return true end
    end
    return false
end

--- Shallow copy of a table (one level) - used so per-call runtime state
--- never mutates the shared Config tables
function MozzyEMS.Utils.ShallowCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

--- Deep copy (recursive) - used when spinning up per-patient runtime vitals
--- from a config template so mutation is always safe
function MozzyEMS.Utils.DeepCopy(tbl)
    if type(tbl) ~= 'table' then return tbl end
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = MozzyEMS.Utils.DeepCopy(v)
    end
    return copy
end

--- Formats seconds as m:ss for score screens / call history
function MozzyEMS.Utils.FormatDuration(seconds)
    seconds = math.floor(seconds or 0)
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format('%d:%02d', m, s)
end

--- Generates a short unique-ish call id, e.g. "C-4821"
function MozzyEMS.Utils.GenerateCallId()
    return string.format('C-%04d', math.random(1000, 9999)) .. '-' .. string.sub(tostring(os.time()), -4)
end

--- vec3-safe distance check without requiring the caller to have natives
--- loaded (kept here so shared context, e.g. weighting locations, can use it)
function MozzyEMS.Utils.Distance(a, b)
    local dx, dy, dz = (a.x - b.x), (a.y - b.y), ((a.z or 0) - (b.z or 0))
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end
