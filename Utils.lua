-- [[ SAUSAGEHEALGRID UTILITIES ]]
-- Táto časť obsahuje pomocné funkcie pre celý addon.

local _, SHG = ...
SHG.Utils = {}

-- [[ VERSION PLACEHOLDER ]]
SHG.VERSION = "SAUSAGE_VERSION"

-- Získanie farby classy podľa jednotky (unit)
function SHG.Utils.GetClassColor(unit, classOverride)
    local class = classOverride
    if not class and unit then
        _, class = UnitClass(unit)
    end
    
    if class then
        local color = RAID_CLASS_COLORS[class]
        if color then
            return color.r, color.g, color.b
        end
    end
    return 0.5, 0.5, 0.5 -- Defaultná šedá
end

-- Výpočet percenta zdravia
function SHG.Utils.GetHealthPercent(unit)
    local max = UnitHealthMax(unit)
    if max == 0 then return 0 end
    return (UnitHealth(unit) / max) * 100
end

-- Formátovanie textu zdravia (napr. 15.5k)
function SHG.Utils.FormatHealth(value)
    if value >= 1000 then
        return string.format("%.1fk", value / 1000)
    end
    return tostring(value)
end

-- Kontrola statusu hráča (Dead/Ghost/Offline)
function SHG.Utils.GetUnitStatus(unit)
    if not UnitIsConnected(unit) then
        return "|cff9fa1a1OFFLINE|r"
    elseif UnitIsGhost(unit) then
        return "|cff9fa1a1GHOST|r"
    elseif UnitIsDead(unit) then
        return "|cffff0000DEAD|r"
    end
    return nil
end

-- Prevod farby RGB na Hex string
function SHG.Utils.RGBToHex(r, g, b)
    return string.format("%02x%02x%02x", r * 255, g * 255, b * 255)
end
