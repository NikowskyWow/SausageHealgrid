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

local _, playerClass = UnitClass("player")
local DispelTypes = {}
if playerClass == "PRIEST" then DispelTypes["Magic"] = true; DispelTypes["Disease"] = true
elseif playerClass == "PALADIN" then DispelTypes["Magic"] = true; DispelTypes["Poison"] = true; DispelTypes["Disease"] = true
elseif playerClass == "DRUID" then DispelTypes["Curse"] = true; DispelTypes["Poison"] = true
elseif playerClass == "SHAMAN" then DispelTypes["Poison"] = true; DispelTypes["Disease"] = true; DispelTypes["Curse"] = true
elseif playerClass == "MAGE" then DispelTypes["Curse"] = true
end

local DispelColors = {
    ["Magic"]   = {0.2, 0.6, 1},
    ["Curse"]   = {0.6, 0, 1},
    ["Disease"] = {0.6, 0.4, 0},
    ["Poison"]  = {0.0, 0.6, 0},
}

local FontPaths = {
    ["Arial Narrow"] = "Fonts\\ARIALN.TTF",
    ["Friz Quadrata TT"] = "Fonts\\FRIZQT__.TTF",
    ["Morpheus"] = "Fonts\\MORPHEUS.TTF",
    ["Skurri"] = "Fonts\\skurri.TTF"
}

local EdgeFiles = {
    ["Blizzard Tooltip"] = "Interface\\Tooltips\\UI-Tooltip-Border",
    ["Solid"] = "Interface\\Buttons\\WHITE8X8",
    ["None"] = ""
}

function SHG.Frames:GetBackdrop()
    local e = EdgeFiles[SHG.DB.borderStyle] or "Interface\\Tooltips\\UI-Tooltip-Border"
    local s = (SHG.DB.borderStyle == "Solid") and 1 or 12
    if SHG.DB.borderStyle == "None" then s = 0 end
    return {bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = e, tile = true, tileSize = 16, edgeSize = s, insets = {left=2,right=2,top=2,bottom=2}}
end

function SHG.Frames:GetHealthColor(u)
    if SHG.DB.healthMode == "Health" then
        local p = math.max(0, math.min(1, UnitHealth(u) / math.max(1, UnitHealthMax(u))))
        local r, g = 1, 1
        if p > 0.5 then r = (1 - p) * 2 else g = p * 2 end
        return r, g, 0
    else
        return SHG.Utils.GetClassColor(u)
    end
end

function SHG.Frames:GetNameColor(u)
    if SHG.DB.nameColorMode == "Custom" then
        return SHG.DB.nameColor.r, SHG.DB.nameColor.g, SHG.DB.nameColor.b
    else
        return SHG.Utils.GetClassColor(u)
    end
end

function SHG.Frames:UpdateAnchor()
    if not self.Anchor then return end
    if SHG.DB.locked then
        self.Anchor:SetAlpha(0)
        self.Anchor:EnableMouse(false)
    else
        self.Anchor:SetAlpha(1)
        self.Anchor:EnableMouse(true)
    end
end

function SHG.Frames:CreateAnchor()
    if self.Anchor then return self.Anchor end
    local w, h = GetDimensions()
    local a = CreateFrame("Frame", "SHG_Anchor", UIParent)
    a:SetSize(w, 20)
    a:SetPoint("CENTER", 0, 100)
    a:SetMovable(true); a:RegisterForDrag("LeftButton")
    a:SetScript("OnDragStart", a.StartMoving); a:SetScript("OnDragStop", a.StopMovingOrSizing)
    a:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = {left=2,right=2,top=2,bottom=2}})
    a:SetBackdropColor(0, 0.7, 1, 0.8)
    local t = a:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t:SetPoint("CENTER"); t:SetText("SHG Anchor")
    self.Anchor = a
    self:UpdateAnchor()
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
    h:SetAttribute("yOffset", SHG.DB.yOffset or -6)
    h:SetAttribute("columnSpacing", SHG.DB.columnSpacing or 6)
    h:SetAttribute("point", "TOP")
    h:SetAttribute("columnAnchorPoint", "LEFT")
    
    h:SetAttribute("initialConfigFunction", string.format([[
        self:SetWidth(%d)
        self:SetHeight(%d)
    ]], w, hDim))
    
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", true)
    h:SetAttribute("showParty", true)
    h:SetAttribute("showRaid", true)
    h:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    -- Bindingy: dynamické podľa aktuálneho profilu (spec)
    local p = SHG:GetProfile()
    for key, action in pairs(p.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = mod and mod ~= "" and mod .. "-" or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        if actType and actVal then
            if actType == "radial" then
                -- Použijeme špeciálnu registráciu pre SecureHandler
                SHG.Radial:RegisterButton(h)
                h:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
            else
                h:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                h:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
            end
        end
    end

    h:SetScript("OnAttributeChanged", function(self, name, val)
        if name:find("^child%d+$") and val and not val.initialized then SHG.Frames:NewUnitFrame(val) end
    end)
    self.Header = h
end

function SHG.Frames:UpdateRoster()
    if InCombatLockdown() then return end
    if not self.Header then self:InitHeader() end
    
    -- Vyčistenie a znovunastavenie bindov pri každom UpdateRoster (talent change)
    if self.Header then
        local p = SHG:GetProfile()
        -- Reset starých (v limite WoW API je lepšie nastaviť nové, staré sa prepíšu)
        for key, action in pairs(p.bindings) do
            local mod, btn = key:match("^(.-)%-?(type%d+)$")
            if not btn then btn = key end
            local prefix = mod and mod ~= "" and mod .. "-" or ""
            local actType, actVal = action:match("^(.-):(.+)$")
            if actType and actVal then
                if actType == "radial" then
                    self.Header:SetAttribute(prefix .. "type" .. btn:match("%d+"), "macro")
                    self.Header:SetAttribute(prefix .. "macrotext" .. btn:match("%d+"), "/run SHG.Radial:Show(GetMouseFocus():GetAttribute('unit'), "..actVal..")")
                else
                    self.Header:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                    self.Header:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
                end
            end
        end
    end

    self.Header:Hide()
    if inRaid then
        self.Header:SetAttribute("showRaid", true)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", false)
    elseif inParty then
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", true)
        self.Header:SetAttribute("showSolo", false)
    else
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", true)
    end
    self.Header:Show()
end

function SHG.Frames:NewUnitFrame(f)
    f.initialized = true
    local w, h = GetDimensions()
    f:SetSize(w, h)
    f:SetBackdrop(self:GetBackdrop())
    f:SetBackdropColor(0, 0, 0, 0.9); f:SetBackdropBorderColor(0, 0.7, 1, 1)
    
    local barH = h - POWER_BAR_HEIGHT - 4
    if not SHG.DB.showMana then barH = h - 4 end
    
    local hp = CreateFrame("StatusBar", nil, f); hp:SetSize(w-4, barH); hp:SetPoint("TOP", 0, -2)
    hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.HealthBar = hp
    
    local pr = CreateFrame("StatusBar", nil, hp); pr:SetAllPoints(hp); pr:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    pr:SetStatusBarColor(0, 1, 0, 0.3); pr:SetFrameLevel(hp:GetFrameLevel()-1); f.PredictBar = pr
    
    local pw = CreateFrame("StatusBar", nil, f); pw:SetSize(w-4, POWER_BAR_HEIGHT); pw:SetPoint("BOTTOM", 0, 2)
    pw:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.PowerBar = pw
    
    local n = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    n:SetPoint("CENTER")
    n:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], 10, "OUTLINE")
    f.Name = n
    
    f.Indicators = {}
    for _, p in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
        local i = hp:CreateTexture(nil, "OVERLAY"); i:SetSize(10, 10)
        i:SetPoint(p, hp, p, p:find("LEFT") and 2 or -2, p:find("TOP") and -2 or 2)
        i:SetTexture("Interface\\Buttons\\WHITE8X8"); i:Hide(); f.Indicators[p] = i
    end
    
    local dFrame = CreateFrame("Button", nil, hp)
    dFrame:SetSize(18, 18); dFrame:SetPoint("CENTER", hp, "CENTER")
    local dTex = dFrame:CreateTexture(nil, "OVERLAY"); dTex:SetAllPoints()
    dFrame.texture = dTex
    dFrame:Hide()
    dFrame:SetScript("OnEnter", function(self)
        if self.index then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnitDebuff(f:GetAttribute("unit"), self.index)
        end
    end)
    dFrame:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.DispelFrame = dFrame
    
    local th = CreateFrame("Frame", nil, f)
    th:SetAllPoints(f); th:SetFrameLevel(f:GetFrameLevel() + 5)
    th:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    th:SetBackdropBorderColor(1, 1, 1, 1); th:Hide(); f.TargetHighlight = th
    
    f:SetScript("OnEvent", function(self, ev, arg)
        local u = self:GetAttribute("unit")
        if ev == "PLAYER_TARGET_CHANGED" then
            if SHG.DB.showTargetHighlight and u and UnitIsUnit(u, "target") then self.TargetHighlight:Show() else self.TargetHighlight:Hide() end
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
            SHG.Frames:UpdateUnit(self, val); SHG.Frames:UpdateAuras(self, val)
        end
    end)
    
    -- Aplikovanie bindings priamo na frame, aby click-casting fungoval 100%
    f:RegisterForClicks("AnyDown", "AnyUp") -- Registrujeme oba eventy pre Hold&Release
    local p = SHG:GetProfile()
    for key, action in pairs(p.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = mod and mod ~= "" and mod .. "-" or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        if btn and actType and actVal then
            if actType == "radial" then
                SHG.Radial:RegisterButton(f)
                f:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
            else
                f:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                f:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
            end
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
    local _, cl = UnitClass("player"); local iT = Indicators[cl]
    if iT then
        for p, sID in pairs(iT) do
            local n = GetSpellInfo(sID); local _, _, icon = UnitBuff(u, n)
            if icon then f.Indicators[p]:SetTexture(icon); f.Indicators[p]:Show() else f.Indicators[p]:Hide() end
        end
    end

    local hasDispel = false
    if SHG.DB.showDispels then
        for i = 1, 40 do
            local name, _, icon, count, debuffType = UnitDebuff(u, i)
            if not name then break end
            if debuffType and DispelTypes[debuffType] then
                f.DispelFrame.texture:SetTexture(icon)
                f.DispelFrame.index = i
                f.DispelFrame:Show()
                local c = DispelColors[debuffType]
                f.HealthBar:SetStatusBarColor(c[1], c[2], c[3], 1)
                hasDispel = true
                break
            end
        end
    end
    
    if not hasDispel then
        f.DispelFrame:Hide()
        f.HealthBar:SetStatusBarColor(self:GetHealthColor(u))
    end
end

function SHG.Frames:UpdateUnit(f, u)
    if not UnitExists(u) then return end
    
    if SHG.DB.showTargetHighlight and UnitIsUnit(u, "target") then f.TargetHighlight:Show() else f.TargetHighlight:Hide() end
    
    local cur, max = UnitHealth(u), UnitHealthMax(u)
    f.HealthBar:SetMinMaxValues(0, max); f.HealthBar:SetValue(cur)
    f.Name:SetText(SHG.Utils.GetUnitStatus(u) or UnitName(u))
    f.Name:SetTextColor(self:GetNameColor(u))
    
    local w, h = GetDimensions()
    f:SetBackdrop(self:GetBackdrop())
    f.Name:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], 10, "OUTLINE")
    
    if SHG.DB.showMana then
        f.HealthBar:SetHeight(h - POWER_BAR_HEIGHT - 4)
        f.PowerBar:SetMinMaxValues(0, UnitPowerMax(u)); f.PowerBar:SetValue(UnitPower(u))
        local c = PowerBarColor[UnitPowerType(u)] or {r=0, g=0.5, b=1}; f.PowerBar:SetStatusBarColor(c.r, c.g, c.b); f.PowerBar:Show()
    else 
        f.HealthBar:SetHeight(h - 4)
        f.PowerBar:Hide() 
    end
    
    -- Toto opraví farbu healthbaru v prípade, že je (alebo nie je) zrovna debuff
    self:UpdateAuras(f, u)
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
        self.Header:Hide()
        local w, h = GetDimensions()
        for i = 1, 5 do
            if not self.TestFrames then self.TestFrames = {} end
            if not self.TestFrames[i] then
                local f = CreateFrame("Frame", nil, UIParent)
                f:SetSize(w, h)
                if i == 1 then
                    f:SetPoint("TOPLEFT", self.Anchor, "BOTTOMLEFT", 0, -5)
                else
                    f:SetPoint("TOPLEFT", self.TestFrames[i-1], "BOTTOMLEFT", 0, SHG.DB.yOffset or -6)
                end
                f:SetBackdrop(self:GetBackdrop())
                f:SetBackdropColor(0,0,0,1); f:SetBackdropBorderColor(1,0.8,0,1)
                
                local barH = h - POWER_BAR_HEIGHT - 4
                if not SHG.DB.showMana then barH = h - 4 end
                
                local hp = CreateFrame("StatusBar", nil, f); hp:SetSize(w-4, barH); hp:SetPoint("TOP", 0, -2)
                hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); hp:SetStatusBarColor(0.2,0.8,0.2)
                local t = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); t:SetPoint("CENTER"); t:SetText("Test Unit "..i)
                t:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], 10, "OUTLINE")
                self.TestFrames[i] = f
            end
            
            -- Updating bounds for test frames if they exist
            self.TestFrames[i]:SetSize(w, h)
            self.TestFrames[i]:SetBackdrop(self:GetBackdrop())
            if i > 1 then self.TestFrames[i]:SetPoint("TOPLEFT", self.TestFrames[i-1], "BOTTOMLEFT", 0, SHG.DB.yOffset or -6) end
            local barH = h - (SHG.DB.showMana and (POWER_BAR_HEIGHT + 4) or 4)
            self.TestFrames[i]:GetChildren():SetSize(w-4, barH)
            
            self.TestFrames[i]:Show()
        end
    else
        if self.TestFrames then for _, f in pairs(self.TestFrames) do f:Hide() end end
        if self.Header and not InCombatLockdown() then self.Header:Show() end
    end
end
