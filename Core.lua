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
        minimapPos = 220,
        bindings = {
            ["type1"] = "spell:Flash of Light",
            ["type2"] = "spell:Holy Light",
            ["shift-type1"] = "spell:Cleanse",
            ["ctrl-type1"] = "spell:Holy Shock",
        }
    }
}

-- [[ HLAVNÝ RÁM LOGIKY ]]
local Core = CreateFrame("Frame")
Core:RegisterEvent("ADDON_LOADED")
Core:RegisterEvent("PLAYER_LOGIN") -- Dôležité pre Secure State Driver
Core:RegisterEvent("RAID_ROSTER_UPDATE")
Core:RegisterEvent("PARTY_MEMBERS_CHANGED")

-- Event handler
Core:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local name = ...
        if name == addonName then
             -- Prvé načítanie dát
             SausageHealgridDB = SausageHealgridDB or defaults.profile
             SHG.DB = SausageHealgridDB
        end
    elseif event == "PLAYER_LOGIN" then
        -- Tu už Blizzard pozná všetky Secure funkcie
        self:Initialize()
        if SHG.Frames then SHG.Frames:UpdateRoster() end
    elseif event == "PLAYER_ENTERING_WORLD" then
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

function SHG:CreateMinimapButton()
    SHG.DB.minimapPos = SHG.DB.minimapPos or 220
    
    local btn = CreateFrame("Button", "SHG_MinimapButton", Minimap)
    btn:SetSize(32, 32)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetTexture("Interface\\Icons\\Spell_Holy_Restoration")
    icon:SetSize(21, 21)
    icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
    
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)
    
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
    
    btn:RegisterForDrag("LeftButton")
    btn:SetMovable(true)
    
    local function UpdatePosition()
        local angle = math.rad(SHG.DB.minimapPos)
        local x = math.cos(angle) * 80
        local y = math.sin(angle) * 80
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end
    
    btn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function()
            local xpos, ypos = GetCursorPosition()
            local xmin, ymin = Minimap:GetLeft(), Minimap:GetBottom()
            local scale = Minimap:GetEffectiveScale()
            xpos = (xpos / scale) - xmin - 70
            ypos = (ypos / scale) - ymin - 70
            local angle = math.deg(math.atan2(ypos, xpos))
            if angle < 0 then angle = angle + 360 end
            SHG.DB.minimapPos = angle
            UpdatePosition()
        end)
    end)
    
    btn:SetScript("OnDragStop", function(self)
        self:UnlockHighlight()
        self:SetScript("OnUpdate", nil)
    end)
    
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine(SHG.Title, 1, 1, 1)
        GameTooltip:AddLine("Left Click: Toggle Config", 1, 0.8, 0)
        GameTooltip:AddLine("Right Click: Toggle Test Mode", 1, 0.8, 0)
        GameTooltip:AddLine("Drag: Move Icon", 1, 0.8, 0)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
    end)
    
    UpdatePosition()
end

-- Inicializácia addonu
function Core:Initialize()
    -- Nastavenie databázy
    SausageHealgridDB = SausageHealgridDB or defaults.profile
    SHG.DB = SausageHealgridDB

    -- Vytvorenie Minimap ikony
    SHG:CreateMinimapButton()

    -- Registrácia Slash commandov
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
