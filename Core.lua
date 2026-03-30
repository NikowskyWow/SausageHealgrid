-- [[ SAUSAGEHEALGRID CORE ]]
-- Hlavná logika addonu, inicializácia a správa eventov.

local addonName, SHG = ...
_G["SHG"] = SHG -- Expose globally for macros and other addons

-- [[ VERZIA A AUTOR ]]
SHG.Title = "|cffff8800Sausage|rHealgrid"
SHG.Author = "Sausage Party / Kokotiar"
SHG.Version = "SAUSAGE_VERSION"

-- Defaultné nastavenia pre databázu
local defaults = {
    profile = {
        gridScale = 1.0,
        frameWidth = 80,
        showMana = true,
        showRage = true,
        showEnergy = true,
        showRunicPower = true,
        showIncomingHeals = true,
        showRangeAlpha = true,
        showDispels = true,
        minimapPos = 220,
        locked = false,
        anchorX = 0,
        anchorY = 100,
        showInSolo = true,
        showInParty = true,
        showInRaid = true,
        frameColorMode = "Class",
        frameCustomColor = {r=0, g=1, b=0}, -- Full HP color for Custom mode
        frameCustomColorLow = {r=1, g=0, b=0}, -- Low HP color for Custom mode
        missingHpColor = {r=0.1, g=0.1, b=0.1},
        hpTextMode = "None",
        fullHpFade = false,
        fullHpThreshold = 95,
        fadeAlpha = 0.3,
        aggroFade = false,
        aggroHighlight = true,
        nameColorMode = "Class",
        nameColor = {r=1, g=1, b=1},
        nameFontSize = 10,
        fontName = "Friz Quadrata TT",
        borderStyle = "Blizzard Tooltip",
        columnSpacing = 6,
        xOffset = 0,
        yOffset = -6,
        maxColumns = 8,
        unitsPerColumn = 5,
        trackedBuffs = {
            ["PRIEST"] = { [1] = 13908, [2] = 17, [3] = 33076, [4] = 48068 }, -- Renew, Shield, PoM, Flash Heal HoT
            ["PALADIN"] = { [1] = 53563, [2] = 53601 }, -- Beacon, Sacred Shield
            ["DRUID"] = { [1] = 774, [2] = 8936, [3] = 48438, [4] = 33763 }, -- Rejuv, Regrowth, Wild Growth, Lifebloom
            ["SHAMAN"] = { [1] = 974, [2] = 61295, [3] = 52000 }, -- Earth Shield, Riptide, Earthliving
        },
        trackedDebuffs = {
            [1] = "Weakened Soul",
            [2] = "Forbearance",
            [3] = "Sated",
            [4] = "Exhaustion"
        },
        priorityUnits = {}, -- List of names to highlight
        profiles = {
            [1] = { name = "Primary", bindings = {} },
            [2] = { name = "Secondary", bindings = {} },
        },
        radialMenus = {
            [1] = { -- Menu 1 (8 slots)
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
            },
            [2] = { -- Menu 2
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
            },
            [3] = { -- Menu 3
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
                { spell = "None" }, { spell = "None" }, { spell = "None" }, { spell = "None" },
            }
        },
        layoutMode = "Column",
    }
}

-- [[ HLAVNÝ RÁM LOGIKY ]]
local Core = CreateFrame("Frame")
Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_LOGIN")
Core:RegisterEvent("RAID_ROSTER_UPDATE")
Core:RegisterEvent("PARTY_MEMBERS_CHANGED")
Core:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
Core:RegisterEvent("PLAYER_TALENT_UPDATE")

-- Získanie mena talentovej vetvy (napr. "Holy")
local function GetSpecName()
    local bestTab, maxPoints = 1, -1
    for i=1, 3 do
        local _, _, points = GetTalentTabInfo(i)
        if points > maxPoints then maxPoints = points; bestTab = i end
    end
    local name = GetTalentTabInfo(bestTab)
    return name or "Unknown"
end

-- Získanie aktuálneho profilu podľa talentov
function SHG:GetProfile()
    local spec = GetActiveTalentGroup() or 1
    if not SHG.DB.profiles[spec] then SHG.DB.profiles[spec] = { name = "Spec "..spec, bindings = {} } end
    -- Automatické premenovanie podľa aktuálnych talentov
    SHG.DB.profiles[spec].name = GetSpecName()
    return SHG.DB.profiles[spec]
end

-- Získanie vizuálneho profilu (Raid / Party)
function SHG:GetVisuals()
    local mode = "Party"
    if SHG.Frames and SHG.Frames.testMode == 2 then mode = "Raid"
    elseif GetNumRaidMembers() > 0 then mode = "Raid" end
    
    if not SHG.DB.visualProfiles then
        SHG.DB.visualProfiles = { Party = {}, Raid = {} }
        local keys = {"gridScale", "frameWidth", "frameHeight", "columnSpacing", "yOffset", "nameFontSize", "fullHpThreshold", "fadeAlpha", "maxColumns", "unitsPerColumn"}
        for _, k in ipairs(keys) do
            SHG.DB.visualProfiles.Party[k] = SHG.DB[k]
            SHG.DB.visualProfiles.Raid[k] = SHG.DB[k]
        end
    end
    -- Fallback pre chýbajúce hodnoty
    local keys = {"gridScale", "frameWidth", "frameHeight", "columnSpacing", "yOffset", "nameFontSize", "fullHpThreshold", "fadeAlpha", "maxColumns", "unitsPerColumn"}
    for _, k in ipairs(keys) do
        if SHG.DB.visualProfiles[mode][k] == nil then SHG.DB.visualProfiles[mode][k] = SHG.DB[k] or defaults.profile[k] end
    end
    return SHG.DB.visualProfiles[mode]
end

-- Event handler
Core:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
             self:InitializeDB()
        end
    elseif event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        if not self.initialized then self:Initialize(); self.initialized = true end
        if SHG.Frames then SHG.Frames:UpdateRoster() end
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_TALENT_UPDATE" then
        -- Pri zmene talentov musíme pre-aplikovať bindy na frame-y
        if SHG.Frames then SHG.Frames:UpdateRoster() end
    elseif event == "RAID_ROSTER_UPDATE" or event == "PARTY_MEMBERS_CHANGED" then
        if not InCombatLockdown() then
            if SHG.Frames then SHG.Frames:UpdateRoster() end
        else
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
        end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if SHG.Frames then SHG.Frames:UpdateRoster() end
        self:UnregisterEvent("PLAYER_REGEN_ENABLED")
    end
end)

function Core:InitializeDB()
    SausageHealgridDB = SausageHealgridDB or {}
    for k, v in pairs(defaults.profile) do
        if SausageHealgridDB[k] == nil then
            SausageHealgridDB[k] = v
        end
    end
    SHG.DB = SausageHealgridDB
    
    -- MIGRÁCIA STARÝCH BINDINGOV (ak existujú v root-e)
    if SHG.DB.bindings and next(SHG.DB.bindings) then
        for k, v in pairs(SHG.DB.bindings) do
            SHG.DB.profiles[1].bindings[k] = v
        end
        SHG.DB.bindings = nil -- Odstránime starú štruktúru
    end
end

function SHG:CreateMinimapButton()
    SHG.DB.minimapPos = SHG.DB.minimapPos or 220
    
    local btn = CreateFrame("Button", "SHG_MinimapButton", Minimap)
    btn:SetSize(31, 31); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_Restoration"); icon:SetSize(20, 20); icon:SetPoint("CENTER")
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(52, 52); border:SetPoint("TOPLEFT")
    border:SetVertexColor(1, 0.6, 0) -- Sausage Party Orange
    
    local badge = btn:CreateTexture(nil, "OVERLAY")
    badge:SetTexture("Interface\\Icons\\Inv_Misc_Food_53")
    badge:SetSize(12, 12); badge:SetPoint("BOTTOMRIGHT", -2, 2)
    
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            SHG.Config:Toggle()
        elseif button == "RightButton" then
            if SHG.Frames then
                SHG.Frames.testMode = ((SHG.Frames.testMode or 0) + 1) % 3
                SHG.Frames:ToggleTestMode(SHG.Frames.testMode)
            end
        end
    end)
    
    btn:RegisterForDrag("LeftButton"); btn:SetMovable(true)
    
    local function UpdatePosition()
        local angle = math.rad(SHG.DB.minimapPos)
        local x, y = math.cos(angle) * 80, math.sin(angle) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    btn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local scale = Minimap:GetEffectiveScale()
            xpos, ypos = (xpos / scale) - xmin - 70, (ypos / scale) - ymin - 70
            local angle = math.deg(math.atan2(ypos, xpos))
            if angle < 0 then angle = angle + 360 end
            SHG.DB.minimapPos = angle
            UpdatePosition()
        end)
    end)
    
    btn:SetScript("OnDragStop", function(self) self:UnlockHighlight(); self:SetScript("OnUpdate", nil) end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(SHG.Title, 1, 1, 1)
        GameTooltip:AddLine("|cffff8800Sausage Party Member|r")
        GameTooltip:AddLine("Left Click: Toggle Config", 1, 0.8, 0)
        GameTooltip:AddLine("Right Click: Toggle Test Mode", 1, 0.8, 0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    
    UpdatePosition()
end

-- Inicializácia addonu
function Core:Initialize()
    SHG:CreateMinimapButton()

    SLASH_SAUSAGEHEALGRID1 = "/shg"
    SLASH_SAUSAGEHEALGRID2 = "/sausagehealgrid"
    SlashCmdList["SAUSAGEHEALGRID"] = function(msg)
        if msg == "config" or msg == "" then
            SHG.Config:Toggle()
        elseif msg == "test" then
            if SHG.Frames then
                SHG.Frames.testMode = ((SHG.Frames.testMode or 0) + 1) % 3
                SHG.Frames:ToggleTestMode(SHG.Frames.testMode)
            end
        elseif msg == "radial" then
            if SHG_RadialMenu then
                SHG_RadialMenu:SetAttribute("hoveredUnit", "player")
                SHG_RadialMenu:SetAttribute("activeUnit", "player")
                SHG_RadialMenu:SetAttribute("activeRadialID", "1")
                SHG_RadialMenu:Show()
                print(SHG.Title .. ": Radial Debug - Forced Show on 'player'")
            else
                print(SHG.Title .. ": Radial Debug - SHG_RadialMenu not found!")
            end
        else
            print(SHG.Title .. ": Use /shg config, /shg test or /shg radial.")
        end
    end

    print(SHG.Title .. " |cff00ff00v" .. SHG.Version .. "|r loaded. [Sausage Party Edition]")
end
