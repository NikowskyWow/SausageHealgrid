-- [[ SAUSAGEHEALGRID CORE ]]
-- Hlavná logika addonu, inicializácia a správa eventov.

local addonName, SHG = ...

-- [[ VERZIA A AUTOR ]]
SHG.Title = "|cFFFFD100Sausage|rHealgrid"
SHG.Author = "Sausage Party / Kokotiar"
SHG.Version = "SAUSAGE_VERSION"

-- Defaultné nastavenia pre databázu
local defaults = {
    profile = {
        gridScale = 1.0,
        frameWidth = 80,
        frameHeight = 45,
        showMana = true,
        showIncomingHeals = true,
        showRangeAlpha = true,
        showDispels = true,
        minimapPos = 220,
        locked = false,
        healthMode = "Class",
        nameColorMode = "Class",
        nameColor = {r=1, g=1, b=1},
        fontName = "Friz Quadrata TT",
        borderStyle = "Blizzard Tooltip",
        columnSpacing = 6,
        xOffset = 0,
        yOffset = -6,
        profiles = {
            [1] = { name = "Primary", bindings = {} },
            [2] = { name = "Secondary", bindings = {} },
        }
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
    btn:SetSize(32, 32); btn:SetFrameStrata("MEDIUM"); btn:SetFrameLevel(8)
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_Restoration"); icon:SetSize(21, 21); icon:SetPoint("CENTER")
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder"); border:SetSize(54, 54); border:SetPoint("TOPLEFT")
    
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            SHG.Config:Toggle()
        elseif button == "RightButton" then
            if SHG.Frames then
                SHG.Frames.testMode = not SHG.Frames.testMode
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
                SHG.Frames.testMode = not SHG.Frames.testMode
                SHG.Frames:ToggleTestMode(SHG.Frames.testMode)
            end
        else
            print(SHG.Title .. ": Use /shg config or /shg test.")
        end
    end

    print(SHG.Title .. " version " .. SHG.Version .. " loaded. Type /shg for config.")
end
