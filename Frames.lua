-- [[ SAUSAGEHEALGRID FRAMES ]]
-- Logika tvorby a aktualizácie unit framov (Partia / Raid) s podporou pre knižnice.

local addonName, SHG = ...
SHG.Frames = {}

-- [[ LIBRARIES ]]
local LibHealComm = LibStub("LibHealComm-4.0", true)
local LibRangeCheck = LibStub("LibRangeCheck-2.0", true)

local POWER_BAR_HEIGHT = 6

local function GetDimensions()
    local w = (SHG.DB and SHG.DB.frameWidth) or 80
    local h = (SHG.DB and SHG.DB.frameHeight) or 45
    return w, h
end

local Indicators = {
    ["PRIEST"] = { ["TOPLEFT"] = 13908, ["TOPRIGHT"] = 17, ["BOTTOMLEFT"] = 33076 },
    ["PALADIN"] = { ["TOPRIGHT"] = 53563, ["BOTTOMLEFT"] = 53601 },
    ["DRUID"] = { ["TOPLEFT"] = 774, ["TOPRIGHT"] = 8936, ["BOTTOMLEFT"] = 48438, ["BOTTOMRIGHT"] = 33763 },
    ["SHAMAN"] = { ["TOPRIGHT"] = 974, ["BOTTOMLEFT"] = 61295 }
}

function SHG.Frames:CreateAnchor()
    if self.Anchor then return self.Anchor end
    local w, h = GetDimensions()
    local a = CreateFrame("Frame", "SHG_Anchor", UIParent)
    a:SetSize(w, 20)
    a:SetPoint("CENTER", 0, 100)
    a:SetMovable(true); a:EnableMouse(true); a:RegisterForDrag("LeftButton")
    a:SetScript("OnDragStart", a.StartMoving); a:SetScript("OnDragStop", a.StopMovingOrSizing)
    a:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2}})
    a:SetBackdropColor(0, 0.7, 1, 0.8)
    local t = a:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t:SetPoint("CENTER"); t:SetText("SHG Anchor")
    self.Anchor = a
    return a
end

function SHG.Frames:InitHeader()
    if self.Header then return end
    local a = self:CreateAnchor()
    local h = CreateFrame("Frame", "SHG_RaidHeader", UIParent, "SecureGroupHeaderTemplate")
    h:SetPoint("TOPLEFT", a, "BOTTOMLEFT", 0, -5)
    
    local w, hDim = GetDimensions()
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("initial-width", tostring(w))
    h:SetAttribute("initial-height", tostring(hDim))
    h:SetAttribute("unitsPerColumn", 5)
    h:SetAttribute("maxColumns", 8)
    h:SetAttribute("xOffset", 0)
    h:SetAttribute("yOffset", -6)
    h:SetAttribute("columnSpacing", 6)
    h:SetAttribute("point", "TOP")
    h:SetAttribute("columnAnchorPoint", "LEFT")
    
    -- Tento hook je absolútne kľúčový vo WotLK pre správnu veľkosť okien v gride pred ich načítaním
    h:SetAttribute("initialConfigFunction", string.format([[
        self:SetWidth(%d)
        self:SetHeight(%d)
    ]], w, hDim))
    
    -- Zapneme videnie sa, aj keď je hráč sám, v partii alebo v raide
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", true)
    h:SetAttribute("showParty", true)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    
    -- Bindingy: oprava logiky (spell1, type1...)
    for key, action in pairs(SHG.DB.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = mod and mod ~= "" and mod .. "-" or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        h:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
        h:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
    end

    h:SetScript("OnAttributeChanged", function(self, name, val)
        if name:find("^child%d+$") and val and not val.initialized then SHG.Frames:NewUnitFrame(val) end
    end)
    self.Header = h
end

function SHG.Frames:UpdateRoster()
    if InCombatLockdown() then return end
    if not self.Header then self:InitHeader() end
    
    local inRaid = GetNumRaidMembers() > 0
    local inParty = GetNumPartyMembers() > 0
    
    self.Header:Hide()
    if inRaid then
        self.Header:SetAttribute("showRaid", true)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", false)
        self.Header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    elseif inParty then
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", true)
        self.Header:SetAttribute("showSolo", false)
        self.Header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    else
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", true)
        self.Header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    end
    self.Header:Show()
end

-- [[ UNIT FRAME ]]
function SHG.Frames:NewUnitFrame(f)
    f.initialized = true
    local w, h = GetDimensions()
    f:SetSize(w, h) -- POISTKA: natvrdo velkost pre istotu
    f:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2}})
    f:SetBackdropColor(0, 0, 0, 0.9); f:SetBackdropBorderColor(0, 0.7, 1, 1)
    
    local barH = h - POWER_BAR_HEIGHT - 4
    if not SHG.DB.showMana then barH = h - 4 end
    
    local hp = CreateFrame("StatusBar", nil, f); hp:SetSize(w-4, barH); hp:SetPoint("TOP", 0, -2)
    hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.HealthBar = hp
    
    local pr = CreateFrame("StatusBar", nil, hp); pr:SetAllPoints(hp); pr:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    pr:SetStatusBarColor(0, 1, 0, 0.3); pr:SetFrameLevel(hp:GetFrameLevel()-1); f.PredictBar = pr
    
    local pw = CreateFrame("StatusBar", nil, f); pw:SetSize(w-4, POWER_BAR_HEIGHT); pw:SetPoint("BOTTOM", 0, 2)
    pw:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.PowerBar = pw
    
    local n = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); n:SetPoint("CENTER"); f.Name = n
    
    f.Indicators = {}
    for _, p in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
        local i = hp:CreateTexture(nil, "OVERLAY"); i:SetSize(10, 10)
        i:SetPoint(p, hp, p, p:find("LEFT") and 2 or -2, p:find("TOP") and -2 or 2)
        i:SetTexture("Interface\\Buttons\\WHITE8X8"); i:Hide(); f.Indicators[p] = i
    end
    
    local th = CreateFrame("Frame", nil, f)
    th:SetAllPoints(f); th:SetFrameLevel(f:GetFrameLevel() + 5)
    th:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    th:SetBackdropBorderColor(1, 1, 1, 1); th:Hide(); f.TargetHighlight = th
    
    f:SetScript("OnEvent", function(self, ev, arg)
        local u = self:GetAttribute("unit")
        if ev == "PLAYER_TARGET_CHANGED" then
            if SHG.DB.showTargetHighlight and u and UnitIsUnit(u, "target") then
                self.TargetHighlight:Show()
            else
                self.TargetHighlight:Hide()
            end
            return
        end
        if not u or (arg and arg ~= u) then return end
        if ev:find("AURA") then SHG.Frames:UpdateAuras(self, u) else SHG.Frames:UpdateUnit(self, u) end
    end)
    f:RegisterEvent("UNIT_HEALTH"); f:RegisterEvent("UNIT_MAXHEALTH"); f:RegisterEvent("UNIT_POWER")
    f:RegisterEvent("UNIT_MAXPOWER"); f:RegisterEvent("UNIT_AURA"); f:RegisterEvent("UNIT_CONNECTION")
    f:RegisterEvent("PLAYER_TARGET_CHANGED")
    
    f:HookScript("OnAttributeChanged", function(self, attr, val)
        if attr == "unit" and val then
            SHG.Frames:UpdateUnit(self, val)
            SHG.Frames:UpdateAuras(self, val)
        end
    end)
    
    -- Aplikovanie bindings priamo na frame, aby click-casting fungoval 100%
    f:RegisterForClicks("AnyUp")
    for key, action in pairs(SHG.DB.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = mod and mod ~= "" and mod .. "-" or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        if btn and actType and actVal then
            f:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
            f:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
        end
    end
    
    f:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        if self.t >= 0.2 then
            self.t = 0; local u = self:GetAttribute("unit")
            if u and LibRangeCheck then local _, m = LibRangeCheck:GetRange(u); self:SetAlpha((m and m > 40) and 0.5 or 1.0) end
            SHG.Frames:UpdateHeals(self, u)
        end
    end)
    local u = f:GetAttribute("unit"); if u then SHG.Frames:UpdateUnit(f, u); SHG.Frames:UpdateAuras(f, u) end
end

function SHG.Frames:UpdateAuras(f, u)
    local _, cl = UnitClass("player"); local iT = Indicators[cl]; if not iT then return end
    for p, sID in pairs(iT) do
        local n = GetSpellInfo(sID); local _, _, icon = UnitBuff(u, n)
        if icon then f.Indicators[p]:SetTexture(icon); f.Indicators[p]:Show() else f.Indicators[p]:Hide() end
    end
end

function SHG.Frames:UpdateUnit(f, u)
    if not UnitExists(u) then return end
    
    if SHG.DB.showTargetHighlight and UnitIsUnit(u, "target") then
        f.TargetHighlight:Show()
    else
        f.TargetHighlight:Hide()
    end
    
    local cur, max = UnitHealth(u), UnitHealthMax(u)
    f.HealthBar:SetMinMaxValues(0, max); f.HealthBar:SetValue(cur)
    f.HealthBar:SetStatusBarColor(SHG.Utils.GetClassColor(u))
    f.Name:SetText(SHG.Utils.GetUnitStatus(u) or UnitName(u))
    
    local w, h = GetDimensions()
    if SHG.DB.showMana then
        f.HealthBar:SetHeight(h - POWER_BAR_HEIGHT - 4)
        f.PowerBar:SetMinMaxValues(0, UnitPowerMax(u)); f.PowerBar:SetValue(UnitPower(u))
        local c = PowerBarColor[UnitPowerType(u)] or {r=0, g=0.5, b=1}; f.PowerBar:SetStatusBarColor(c.r, c.g, c.b); f.PowerBar:Show()
    else 
        f.HealthBar:SetHeight(h - 4)
        f.PowerBar:Hide() 
    end
end

function SHG.Frames:UpdateHeals(f, u)
    if LibHealComm and SHG.DB.showIncomingHeals then
        local inc = LibHealComm:GetHealAmount(u, LibHealComm.ALL_HEALS) or 0
        if inc > 0 then f.PredictBar:SetMinMaxValues(0, UnitHealthMax(u)); f.PredictBar:SetValue(UnitHealth(u)+inc); f.PredictBar:Show(); return end
    end
    f.PredictBar:Hide()
end

function SHG.Frames:ToggleTestMode(show)
    if show then
        if not self.Header then self:InitHeader() end
        self.Header:Hide() -- Schova real grid pod nim
        local w, h = GetDimensions()
        for i = 1, 5 do
            if not self.TestFrames then self.TestFrames = {} end
            if not self.TestFrames[i] then
                local f = CreateFrame("Frame", nil, UIParent)
                f:SetSize(w, h)
                if i == 1 then
                    f:SetPoint("TOPLEFT", self.Anchor, "BOTTOMLEFT", 0, -5)
                else
                    f:SetPoint("TOPLEFT", self.TestFrames[i-1], "BOTTOMLEFT", 0, -6)
                end
                f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", tile=true, tileSize=16, edgeSize=12, insets={left=2,right=2,top=2,bottom=2}})
                f:SetBackdropColor(0,0,0,1); f:SetBackdropBorderColor(1,0.8,0,1)
                
                local barH = h - POWER_BAR_HEIGHT - 4
                if not SHG.DB.showMana then barH = h - 4 end
                
                local hp = CreateFrame("StatusBar", nil, f); hp:SetSize(w-4, barH); hp:SetPoint("TOP", 0, -2)
                hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); hp:SetStatusBarColor(0.2,0.8,0.2)
                local t = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t:SetPoint("CENTER"); t:SetText("Test Unit "..i)
                self.TestFrames[i] = f
            end
            self.TestFrames[i]:Show()
        end
    else
        if self.TestFrames then for _, f in pairs(self.TestFrames) do f:Hide() end end
        if self.Header and not InCombatLockdown() then self.Header:Show() end
    end
end
