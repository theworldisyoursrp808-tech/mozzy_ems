--[[
    bridge/inventory.lua (server-only)
    All ox_inventory contact goes through here. Item add/remove is ALWAYS
    server-authoritative - the client never tells the server it "has" an item.
]]

MozzyEMS = MozzyEMS or {}
MozzyEMS.Inventory = {}

--- Returns true if the player has at least `amount` of the given
--- Config.Items key (not the raw ox_inventory item name - callers pass the
--- config key, e.g. 'bandage', and this resolves it).
function MozzyEMS.Inventory.HasItem(source, itemKey, amount)
    amount = amount or 1
    local itemName = Config.Items[itemKey]
    if not itemName then return true end -- unmapped key = treat as "no item required"
    local ok, count = pcall(function()
        return exports.ox_inventory:Search(source, 'count', itemName)
    end)
    if not ok or not count then return false end
    return count >= amount
end

--- Removes `amount` of an item. Only call this after HasItem already
--- passed and the behaviour table says it should be consumed.
function MozzyEMS.Inventory.RemoveItem(source, itemKey, amount)
    amount = amount or 1
    local itemName = Config.Items[itemKey]
    if not itemName then return true end
    local ok, success = pcall(function()
        return exports.ox_inventory:RemoveItem(source, itemName, amount)
    end)
    return ok and success
end

--- Central "can this player use this treatment right now" item check,
--- respects Config.ItemBehaviour (required / consume) per item key.
--- Returns ok(bool), reason(string|nil)
function MozzyEMS.Inventory.ValidateAndConsume(source, itemKey)
    if not itemKey then return true end -- treatment requires no item (e.g. CPR)
    local behaviour = Config.ItemBehaviour[itemKey] or { required = true, consume = true }
    if not behaviour.required then return true end

    if not MozzyEMS.Inventory.HasItem(source, itemKey, 1) then
        return false, 'missing_item'
    end

    if behaviour.consume then
        local removed = MozzyEMS.Inventory.RemoveItem(source, itemKey, 1)
        if not removed then return false, 'missing_item' end
    end

    return true
end
