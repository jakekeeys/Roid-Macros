--[[
	Author: Dennis Werner Garske (DWG)
	License: MIT License
]]
local _G = _G or getfenv(0)
local Roids = _G.Roids or {}

function print(msg)
    DEFAULT_CHAT_FRAME:AddMessage(msg)
end

-- Validates that the given target is either friend (if [help]) or foe (if [harm])
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy.
-- remarks: Will always return true if help is not given
-- returns: Whether or not the given target can either be attacked or supported, depending on help
function Roids.CheckHelp(target, help)
	if help then
		if help == 1 then
            return UnitCanAssist("player", target);
		else
			return UnitCanAttack("player", target);
		end
	end
	return true;
end

-- Ensures the validity of the given target
-- target: The unit id to check
-- help: Optional. If set to 1 then the target must be friendly. If set to 0 it must be an enemy
-- returns: Whether or not the target is a viable target
function Roids.IsValidTarget(target, help)    
	if target ~= "mouseover" then
		if not Roids.CheckHelp(target, help) or not UnitExists(target) then
			return false;
		end
		return true;
	end
	
	if (not Roids.mouseoverUnit) and not UnitName("mouseover") then
		return false;
	end
    
	return Roids.CheckHelp(target, help);
end

-- Returns the current shapeshift / stance index
-- returns: The index of the current shapeshift form / stance. 0 if in no shapeshift form / stance
function Roids.GetCurrentShapeshiftIndex()
    for i=1, GetNumShapeshiftForms() do
        _, _, active = GetShapeshiftFormInfo(i);
        if active then
            return i; 
        end
    end
    
    return 0;
end

function Roids.CancelAura(auraName)
    local ix = 0
    while true do
        local aura_ix = GetPlayerBuff(ix,"HELPFUL")
        ix = ix + 1
        if aura_ix == -1 then break end
        auraName = string.gsub(auraName, "_"," ")
        local bid = GetPlayerBuffID(aura_ix)
        bid = (bid < -1) and bid + 65536 or bid
        if SpellInfo(bid) == auraName then
            CancelPlayerBuff(aura_ix)
            break
        end
    end
end

local function CheckAura(auraName,isbuff,unit)
    local i = 1
    local id = 0
    while id do
        if isbuff then
            _,_,id = UnitBuff(unit,i)
        else
            _,_,_,id = UnitDebuff(unit,i)
        end
        if id and id < -1 then id = id + 65536 end
        auraName = string.gsub(auraName, "_"," ")
        if auraName == SpellInfo(id) then
            return true
        end
        i = i + 1
    end
    return false
end

-- Checks whether or not the given buffName is present on the given unit's buff bar
-- buffName: The name of the buff
-- unit: The UnitID of the unit to check
-- returns: True if the buffName can be found, false otherwhise
function Roids.HasBuffName(buffName, unit)
    if not buffName or not unit or type(buffName) == "table" then
        return false;
    end

    return CheckAura(buffName,true,unit)
end

-- Checks whether or not the given buffName is present on the given unit's debuff bar
-- buffName: The name of the debuff
-- unit: The UnitID of the unit to check
-- returns: True if the buffName can be found, false otherwhise
function Roids.HasDeBuffName(buffName, unit)
    if not buffName or not unit or type(buffName) == "table" then
        return false;
    end

    return CheckAura(buffName,false,unit) or CheckAura(buffName,true,unit)
end

-- Checks whether or not the given textureName is present in the current player's buff bar
-- textureName: The full name (including path) of the texture
-- returns: True if the texture can be found, false otherwhise
function Roids.HasBuff(textureName)
    for i = 1, 16 do
        if UnitBuff("player", i) == textureName then
            return true;
        end
    end
    
    return false;
end

-- Maps easy to use weapon type names (e.g. Axes, Shields) to their inventory slot name and their localized tooltip name
Roids.WeaponTypeNames = {
    Daggers = { slot = "MainHandSlot", name = Roids.Localized.Dagger },
    Fists =  { slot = "MainHandSlot", name = Roids.Localized.FistWeapon },
    Axes =  { slot = "MainHandSlot", name = Roids.Localized.Axe },
    Swords =  { slot = "MainHandSlot", name = Roids.Localized.Sword },
    Staves =  { slot = "MainHandSlot", name = Roids.Localized.Staff },
    Maces =  { slot = "MainHandSlot", name = Roids.Localized.Mace },
    Polearms =  { slot = "MainHandSlot", name = Roids.Localized.Polearm },
    -- OH
    Daggers2 = { slot = "SecondaryHandSlot", name = Roids.Localized.Dagger },
    Fists2 = { slot = "SecondaryHandSlot", name = Roids.Localized.FistWeapon },
    Axes2 = { slot = "SecondaryHandSlot", name = Roids.Localized.Axe },
    Swords2 = { slot = "SecondaryHandSlot", name = Roids.Localized.Sword },
    Maces2 = { slot = "SecondaryHandSlot", name = Roids.Localized.Mace },
    Shields = { slot = "SecondaryHandSlot", name = Roids.Localized.Shield },
    -- ranged
    Guns = { slot = "RangedSlot", name = Roids.Localized.Gun },
    Crossbows = { slot = "RangedSlot", name = Roids.Localized.Crossbow },
    Bows = { slot = "RangedSlot", name = Roids.Localized.Bow },
    Thrown = { slot = "RangedSlot", name = Roids.Localized.Thrown },
    Wands = { slot = "RangedSlot", name = Roids.Localized.Wand },
};

-- Checks whether a given piece of gear is equipped is currently equipped
-- gearId: The name (or item id) of the gear (e.g. Badge_Of_The_Swam_Guard, etc.)
-- returns: True when equipped, otherwhise false
function Roids.HasGearEquipped(gearId)
    local slotLink
    for slotId=1,19 do
        slotLink = GetInventoryItemLink("player",slotId)
        if slotLink then
            local _,_,itemId = string.find(slotLink,"item:(%d+)")
            if gearId == itemId then
                return true
            end
            local gearName = string.gsub(gearId, "_", " ");
            local name,_link,_,_lvl,_type,subtype = GetItemInfo(itemId)
            if name == gearName then
                return true
            end
        end
    end
    return false
end

-- Checks whether or not the given weaponType is currently equipped
-- weaponType: The name of the weapon's type (e.g. Axe, Shield, etc.)
-- returns: True when equipped, otherwhise false
function Roids.HasWeaponEquipped(weaponType)
    if not Roids.WeaponTypeNames[weaponType] then
        return false;
    end
    
    local slotName = Roids.WeaponTypeNames[weaponType].slot;
    local localizedName = Roids.WeaponTypeNames[weaponType].name;
    local slotId = GetInventorySlotInfo(slotName);
    local slotLink = GetInventoryItemLink("player",slotId)
    if not slotLink then
        return false;
    end

    local _,_,itemId = string.find(slotLink,"item:(%d+)")
    local _name,_link,_,_lvl,_type,subtype = GetItemInfo(itemId)
    -- just had to be special huh?
    local fist = string.find(subtype,"^Fist")
    -- drops things like the One-Handed prefix
    local _,_,subtype = string.find(subtype,"%s?(%S+)$")

    if subtype == localizedName or (fist and (Roids.WeaponTypeNames[weaponType].name == Roids.Localized.FistWeapon)) then
        return true
    end

    return false;
end

-- Checks whether or not the given UnitId is in your party or your raid
-- target: The UnitId of the target to check
-- groupType: The name of the group type your target has to be in ("party" or "raid")
-- returns: True when the given target is in the given groupType, otherwhise false
function Roids.IsTargetInGroupType(target, groupType)
    local upperBound = 5;
    if groupType == "raid" then
        upperBound = 40;
    end
    
    -- use UnitIsUnit here? is it faster than name?
    for i = 1, upperBound do
        if UnitName(groupType..i) == UnitName(target) then
            return true;
        end
    end
    
    return false;
end

-- Checks whether or not we're currently casting a channeled spell
function Roids.CheckChanneled(conditionals)
    -- Remove the "(Rank X)" part from the spells name in order to allow downranking
    local spellName = string.gsub(Roids.CurrentSpell.spellName, "%(.-%)%s*", "");
    local channeled = string.gsub(conditionals.checkchanneled, "%(.-%)%s*", "");
    
    if Roids.CurrentSpell.type == "channeled" and spellName == channeled then
        return false;
    end
    
    if channeled == Roids.Localized.Attack then
        return not Roids.CurrentSpell.autoAttack;
    end
    
    if channeled == Roids.Localized.AutoShot then
        return not Roids.CurrentSpell.autoShot;
    end
    
    if channeled == Roids.Localized.Shoot then
        return not Roids.CurrentSpell.wand;
    end
    
    Roids.CurrentSpell.spellName = channeled;
    return true;
end

-- Checks whether or not the given unit has more or less power in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidatePower(unit, bigger, amount)
    local powerPercent = 100 / UnitManaMax(unit) * UnitMana(unit);
    if bigger == 0 then
        return powerPercent < tonumber(amount);
    end
    
    return powerPercent > tonumber(amount);
end

-- Checks whether or not the given unit has more or less total power than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the raw power needs to be bigger, 0 if it needs to be less
-- amount: The required amount
-- returns: True or false
function Roids.ValidateRawPower(unit, bigger, amount)
    local power = UnitMana(unit);
    if bigger == 0 then
        return power < tonumber(amount);
    end
    
    return power > tonumber(amount);
end

-- Checks whether or not the given unit has more or less hp in percent than the given amount
-- unit: The unit we're checking
-- bigger: 1 if the percentage needs to be bigger, 0 if it needs to be lower
-- amount: The required amount
-- returns: True or false
function Roids.ValidateHp(unit, bigger, amount)
    local powerPercent = 100 / UnitHealthMax(unit) * UnitHealth(unit);
    if bigger == 0 then
        return powerPercent < tonumber(amount);
    end
    
    return powerPercent > tonumber(amount);
end

-- Checks whether the given creatureType is the same as the target's creature type
-- creatureType: The type to check
-- target: The target's unitID
-- returns: True or false
-- remarks: Allows for both localized and unlocalized type names
function Roids.ValidateCreatureType(creatureType, target)
    local targetType = UnitCreatureType(target);
    local englishType = Roids.Localized.CreatureTypes[targetType];
    return creatureType == targetType or creatureType == englishType;
end

function Roids.ValidateCooldown(cooldown_data,check_absence)
    local limit,amount
    local name = cooldown_data
    if type(cooldown_data) == "table" then
        limit = cooldown_data.bigger
        amount = tonumber(cooldown_data.amount)
        name = cooldown_data.name
    end
    name = string.gsub(name, "_", " ")

    local cd,start = Roids.GetSpellCooldownByName(name)
    if not cd then cd,start = Roids.GetInventoryCooldownByName(name) end
    if not cd then cd,start = Roids.GetContainerItemCooldownByName(name) end

    if limit == 1 and start ~= 0 then
        return (start + cd - GetTime()) >= amount
    elseif limit == 0 then
        return (start + cd - GetTime()) <= amount
    elseif limit == nil then
        if check_absence then
            -- print("ab: "..name)
            return cd == 0
        else
            -- print("pres: "..name)
            return cd > 0
        end
    end
end

function Roids.ValidatePlayerAura(auta_data,debuff,check_absence)
    local limit,amount
    local name = auta_data
    if type(auta_data) == "table" then
        limit = auta_data.bigger
        amount = tonumber(auta_data.amount)
        name = auta_data.name
    end
    name = string.gsub(name, "_", " ")

    local ix = 0
    local aura_ix = -1
    local rem = 0
    repeat
        aura_ix = GetPlayerBuff(ix,debuff and "HARMFUL" or "HELPFUL")
        ix = ix + 1
        if aura_ix ~= -1 then
            local bid = GetPlayerBuffID(aura_ix)
            bid = (bid < -1) and bid + 65536 or bid
            if SpellInfo(bid) == name then
                rem = GetPlayerBuffTimeLeft(aura_ix)
            end
        end
    until aura_ix == -1

    if limit == 1 and rem ~= 0 then
        return rem >= amount
    elseif limit == 0 then
        return rem <= amount
    elseif limit == nil then
        return check_absence and (aura_ix == -1) or (aura_ix ~= -1)
    end
end

-- Returns the cooldown of the given spellName or nil if no such spell was found
function Roids.GetSpellCooldownByName(spellName)
    local checkFor = function(bookType)
        local i = 1
        while true do
            local name, spellRank = GetSpellName(i, bookType);
            
            if not name then
                break;
            end
            
            if name == spellName then
                -- local _, duration = GetSpellCooldown(i, bookType);
                -- return duration;
                return GetSpellCooldown(i, bookType);
            end
            
            i = i + 1
        end
        return nil;
    end
    
    
    local start,cd = checkFor(BOOKTYPE_PET);
    if not cd then start,cd = checkFor(BOOKTYPE_SPELL); end
    -- print(start)
    -- print(cd)
    
    return cd,start;
end

-- Returns the cooldown of the given equipped itemName or nil if no such item was found
function Roids.GetInventoryCooldownByName(itemName)
    local slotLink = nil
    for i = 0, 19 do
        slotLink = GetInventoryItemLink("player",i)
        if slotLink then
            if itemName == itemId then
                return -i
            end
            local _,_,itemId = string.find(slotLink,"item:(%d+)")
            -- local gearName = string.gsub(itemId, "_", " ");
            local name,_link,_,_lvl,_type,subtype = GetItemInfo(itemId)
            if itemName == itemId or name == itemName then
                local start, duration = GetInventoryItemCooldown("player", i);
                return duration, start
                -- return -i
            end
        end
    end

    -- RoidsTooltip:SetOwner(UIParent, "ANCHOR_NONE");
    -- for i=0, 19 do
    --     RoidsTooltip:ClearLines();
    --     hasItem = RoidsTooltip:SetInventoryItem("player", i);
        
    --     if hasItem then
    --         local lines = RoidsTooltip:NumLines();
            
    --         local label = getglobal("RoidsTooltipTextLeft1");
            
    --         if label:GetText() == itemName then
    --             local start, duration = GetInventoryItemCooldown("player", i);
    --             -- return duration;
    --             return duration, start
    --         end
    --     end
    -- end
    
    return nil;
end

-- Returns the cooldown of the given itemName in the player's bags or nil if no such item was found
function Roids.GetContainerItemCooldownByName(itemName)
    for i = 0, 4 do
        for j = 1, GetContainerNumSlots(i) do
            local l = GetContainerItemLink(i,j)
            if l then _,_,itemId = string.find(l,"item:(%d+)") end
            local name,_link,_,_lvl,_type,subtype = GetItemInfo(itemId)
            if itemId and itemId == itemName or itemName == name then
                local start, duration = GetContainerItemCooldown(i, j);
                -- return duration;
                return duration,start
                -- return i, j;
            end
        end
    end

    -- RoidsTooltip:SetOwner(WorldFrame, "ANCHOR_NONE");
    
    -- for i = 0, 4 do
    --     for j = 1, GetContainerNumSlots(i) do
    --         RoidsTooltip:ClearLines();
    --         RoidsTooltip:SetBagItem(i, j);
    --         if RoidsTooltipTextLeft1:GetText() == itemName then
    --             local start, duration = GetContainerItemCooldown(i, j);
    --             -- return duration;
    --             return duration,start
    --         end
    --     end
    -- end

    return nil;
end

-- A list of Conditionals and their functions to validate them
Roids.Keywords = {
    help = function(conditionals)
        return true;
    end,
    
    harm = function(conditionals)
        return true;
    end,
    
    stance = function(conditionals)
        for _,stances in pairs(conditionals.stance) do
            -- print(stances)
            for k,v in pairs(Roids.splitString(stances, "/")) do
                -- print(v)
                if Roids.GetCurrentShapeshiftIndex() == tonumber(v) then
                    return true
                end
            end
        end
        return false
    end,
    
    mod = function(conditionals)
        for _,mods in pairs(conditionals.mod) do
            for k,v in pairs(Roids.splitString(mods, "/")) do
                if v == "alt" and IsAltKeyDown() then
                    return true
                elseif v == "ctrl" and IsControlKeyDown() then
                    return true
                elseif v == "shift" and IsShiftKeyDown() then
                    return true
                end
            end
        end
        return false

        -- local modifiersPressed = true;
        
        -- for k,v in pairs(Roids.splitString(conditionals.mod, "/")) do
        --     if v == "alt" and not IsAltKeyDown() then
        --         modifiersPressed = false;
        --         break;
        --     elseif v == "ctrl" and not IsControlKeyDown() then
        --         modifiersPressed = false;
        --         break;
        --     elseif v == "shift" and not IsShiftKeyDown() then
        --         modifiersPressed = false;
        --         break;
        --     end
        -- end
        
        -- return modifiersPressed;
    end,
    
    target = function(conditionals)
        return Roids.IsValidTarget(conditionals.target, conditionals.help);
    end,
    
    combat = function(conditionals)
        return UnitAffectingCombat("player");
    end,
    
    nocombat = function(conditionals)
        return not UnitAffectingCombat("player");
    end,
    
    stealth = function(conditionals)
        return Roids.HasBuff("Interface\\Icons\\Ability_Ambush");
    end,
    
    nostealth = function(conditionals)
        return not Roids.HasBuff("Interface\\Icons\\Ability_Ambush");
    end,

    zone = function(conditionals)
        local zone = string.lower(GetRealZoneText())
        for _,zones in pairs(conditionals.zone) do
            local zones = string.gsub(zones, "_", " ");
            for k,v in pairs(Roids.splitString(zones, "/")) do
                -- print(v .. " " .. zone)
                if string.lower(v) == zone then
                    return true
                end
            end
        end
        return false
    end,

    nozone = function(conditionals)
        local zone = string.lower(GetRealZoneText())
        for _,zones in pairs(conditionals.zone) do
            local zones = string.gsub(zones, "_", " ");
            for k,v in pairs(Roids.splitString(zones, "/")) do
                -- print(v .. " " .. zone)
                if string.lower(v) == zone then
                    return false
                end
            end
        end
        return true
    end,

    equipped = function(conditionals)
        for _,equips in pairs(conditionals.equipped) do
            for k,v in pairs(Roids.splitString(equips, "/")) do
                if Roids.HasGearEquipped(v) or Roids.HasWeaponEquipped(v) then
                    return true
                end
            end
        end
        return false
        -- local isEquipped = false
        -- for k,v in pairs(Roids.splitString(conditionals.equipped, "/")) do
        --     if Roids.HasGearEquipped(v) or Roids.HasWeaponEquipped(v) then
        --         isEquipped = true
        --         break
        --     end
        -- end
        -- return isEquipped
    end,

    dead = function(conditionals)
        return UnitIsDeadOrGhost(conditionals.target);
    end,

    nodead = function(conditionals)
        return not UnitIsDeadOrGhost(conditionals.target);
    end,

    party = function(conditionals)
        return Roids.IsTargetInGroupType(conditionals.target, "party");
    end,

    raid = function(conditionals)
        return Roids.IsTargetInGroupType(conditionals.target, "raid");
    end,
    -- TODO: add multi
    group = function(conditionals)
        if conditionals.group == "party" then
            return GetNumPartyMembers() > 0;
        elseif conditionals.group == "raid" then
            return GetNumRaidMembers() > 0;
        end
        return false;
    end,
    
    checkchanneled = function(conditionals)
        return Roids.CheckChanneled(conditionals);
    end,

    buff = function(conditionals)
        for _,v in pairs(conditionals.buff) do
            if not Roids.HasBuffName(v, conditionals.target) then
                return false
            end
        end
        return true
        -- return Roids.HasBuffName(conditionals.buff, conditionals.target);
    end,

    nobuff = function(conditionals)
        for _,v in pairs(conditionals.nobuff) do
            if Roids.HasBuffName(v, conditionals.target) then
                return false
            end
        end
        return true
        -- return not Roids.HasBuffName(conditionals.nobuff, conditionals.target);
    end,

    debuff = function(conditionals)
        for _,v in pairs(conditionals.debuff) do
            if not Roids.HasDeBuffName(v, conditionals.target) then
                return false
            end
        end
        return true
        -- return Roids.HasDeBuffName(conditionals.debuff, conditionals.target);
    end,

    nodebuff = function(conditionals)
        for _,v in pairs(conditionals.nodebuff) do
            if Roids.HasDeBuffName(v, conditionals.target) then
                return false
            end
        end
        return true
        -- return not Roids.HasDeBuffName(conditionals.nodebuff, conditionals.target);
    end,

    mybuff = function(conditionals)
        for k,v in pairs(conditionals.mybuff) do
            if not Roids.ValidatePlayerAura(v,false,false) then
                return false
            end
        end
        return true
        -- return Roids.HasBuffName(conditionals.mybuff, "player");
    end,

    nomybuff = function(conditionals)
        for k,v in pairs(conditionals.nomybuff) do
            if Roids.ValidatePlayerAura(v,false,true) then
                return false
            end
        end
        return true
        -- return not Roids.HasBuffName(conditionals.nomybuff, "player");
    end,

    mydebuff = function(conditionals)
        for k,v in pairs(conditionals.mydebuff) do
            if not Roids.ValidatePlayerAura(v,true,false) then
                return false
            end
        end
        return true
        -- return Roids.HasDeBuffName(conditionals.mydebuff, "player");
    end,

    nomydebuff = function(conditionals)
        for k,v in pairs(conditionals.nomydebuff) do
            if Roids.ValidatePlayerAura(v,true,true) then
                return false
            end
        end
        return true
        -- return not Roids.HasDeBuffName(conditionals.nomydebuff, "player");
    end,
    
    power = function(conditionals)
        for _,v in pairs(conditionals.mypower) do
            if not Roids.ValidatePower(conditionals.target, v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidatePower(conditionals.target, conditionals.power.bigger, conditionals.power.amount);
    end,
    
    mypower = function(conditionals)
        for _,v in pairs(conditionals.mypower) do
            if not Roids.ValidatePower("player", v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidatePower("player", conditionals.mypower.bigger, conditionals.mypower.amount);
    end,
    
    rawpower = function(conditionals)
        for _,v in pairs(conditionals.rawpower) do
            if not Roids.ValidateRawPower(conditionals.target, v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidateRawPower(conditionals.target, conditionals.rawpower.bigger, conditionals.rawpower.amount);
    end,
    
    myrawpower = function(conditionals)
        for _,v in pairs(conditionals.myrawpower) do
            if not Roids.ValidateRawPower("player", v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidateRawPower("player", conditionals.myrawpower.bigger, conditionals.myrawpower.amount);
    end,
    
    hp = function(conditionals)
        for _,v in pairs(conditionals.hp) do
            if not Roids.ValidateHp(conditionals.target, v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidateHp(conditionals.target, conditionals.hp.bigger, conditionals.hp.amount);
    end,
    
    myhp = function(conditionals)
        for _,v in pairs(conditionals.myhp) do
            if not Roids.ValidateHp("player", v.bigger, v.amount) then
                return false
            end
        end
        return true
        -- return Roids.ValidateHp("player", conditionals.myhp.bigger, conditionals.myhp.amount);
    end,
    
    type = function(conditionals)
        return Roids.ValidateCreatureType(conditionals.type, conditionals.target);
    end,
    
    cooldown = function(conditionals)
        for k,v in pairs(conditionals.cooldown) do
            if not Roids.ValidateCooldown(v,false) then
                return false
            end
        end
        return true
    end,
    
    nocooldown = function(conditionals)
        for k,v in pairs(conditionals.nocooldown) do
            -- print("nocooldown: "..k.." "..v)
            if not Roids.ValidateCooldown(v,true) then
                -- print(k)
                -- print(v)
                return false
            end
        end
        return true
        -- local name = string.gsub(conditionals.nocooldown, "_", " ");
        -- local cd = Roids.GetSpellCooldownByName(name);
        -- if not cd then cd = Roids.GetInventoryCooldownByName(name); end
        -- if not cd then cd = Roids.GetContainerItemCooldownByName(name) end
        -- return cd == 0;
    end,
    
    channeled = function(conditionals)
        return Roids.CurrentSpell.spellName ~= "";
    end,
    
    nochanneled = function(conditionals)
        return Roids.CurrentSpell.spellName == "";
    end,
    
    attacks = function(conditionals)
        return UnitIsUnit("targettarget", conditionals.attacks);
    end,
    
    noattacks = function(conditionals)
        return not UnitIsUnit("targettarget", conditionals.noattacks);
    end,
    
    isplayer = function(conditionals)
        return UnitIsPlayer(conditionals.isplayer);
    end,
    
    isnpc = function(conditionals)
        return not UnitIsPlayer(conditionals.isnpc);
    end,
};