-- [[ SAUSAGEHEALGRID FRAMES ]]
-- Logika tvorby a aktualizácie unit framov (Partia / Raid) s podporou pre knižnice.

local addonName, SHG = ...
SHG.Frames = {}

-- [[ LIBRARIES ]]
local LibHealComm = LibStub("LibHealComm-4.0", true)
local LibRangeCheck = LibStub("LibRangeCheck-2.0", true)

local POWER_BAR_HEIGHT = 6

local function GetDimensions()
    local v = SHG:GetVisuals()
    return v.frameWidth or 80, v.frameHeight or 45
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
    if SHG.DB.frameColorMode == "Gradient" then
        local maxHp = UnitHealthMax(u)
        local p = math.max(0, math.min(1, UnitHealth(u) / math.max(1, maxHp)))
        local r, g = 1, 1
        if p > 0.5 then r = (1 - p) * 2 else g = p * 2 end
        return r, g, 0
    elseif SHG.DB.frameColorMode == "Custom" then
        local maxHp = UnitHealthMax(u)
        local p = math.max(0, math.min(1, UnitHealth(u) / math.max(1, maxHp)))
        local full = SHG.DB.frameCustomColor or {r=0,g=1,b=0}
        local low = SHG.DB.frameCustomColorLow or {r=1,g=0,b=0}
        -- Interpolácia medzi Low a Full farbou
        local r = low.r + (full.r - low.r) * p
        local g = low.g + (full.g - low.g) * p
        local b = low.b + (full.b - low.b) * p
        return r, g, b
    else
        return SHG.Utils.GetClassColor(u)
    end
end

function SHG.Frames:GetNameColor(u)
    if SHG.DB.nameColorMode == "Custom" then
        local c = SHG.DB.nameCustomColor or {r=1, g=1, b=1}
        return c.r, c.g, c.b
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
    a:SetPoint("CENTER", UIParent, "BOTTOMLEFT", SHG.DB.anchorX or GetScreenWidth()/2, SHG.DB.anchorY or GetScreenHeight()/2 + 100)
    a:SetMovable(true); a:RegisterForDrag("LeftButton")
    a:SetScript("OnDragStart", a.StartMoving)
    a:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local x, y = self:GetCenter()
        SHG.DB.anchorX = x
        SHG.DB.anchorY = y
    end)
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
    
    local v = SHG:GetVisuals()
    local w, hDim = v.frameWidth, v.frameHeight
    h:SetAttribute("template", "SecureUnitButtonTemplate")
    h:SetAttribute("initial-width", w)
    h:SetAttribute("initial-height", hDim)
    h:SetAttribute("unitsPerColumn", v.unitsPerColumn or 5)
    h:SetAttribute("maxColumns", v.maxColumns or 8)
    h:SetAttribute("columnSpacing", v.columnSpacing or 6)

    -- Sorting and Grouping
    h:SetAttribute("groupBy", "GROUP")
    h:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
    h:SetAttribute("sortMethod", "INDEX")

    local layout = SHG.DB.layoutMode or "Column"
    if layout == "Row" then
        h:SetAttribute("point", "LEFT")
        h:SetAttribute("columnAnchorPoint", "TOP")
        h:SetAttribute("xOffset", v.xOffset or 6)
        h:SetAttribute("yOffset", 0)
    else
        h:SetAttribute("point", "TOP")
        h:SetAttribute("columnAnchorPoint", "LEFT")
        h:SetAttribute("xOffset", 0)
        h:SetAttribute("yOffset", v.yOffset or -6)
    end

    h:SetScale(v.gridScale or 1.0)
    
    -- Combined Initial Config for Child Frames
    -- Combined Initial Config for Child Frames
    h:SetAttribute("initialConfigFunction", string.format([[
        self:SetWidth(%d)
        self:SetHeight(%d)
        self:RegisterForClicks("AnyDown")
    ]], w, hDim))

    -- MUST SET THESE FOR SOLO SUPPORT
    h:SetAttribute("showPlayer", true)
    h:SetAttribute("showSolo", true)
    h:SetAttribute("showParty", true)
    h:SetAttribute("showRaid", true)
    
    h:SetScript("OnAttributeChanged", function(self, name, val)
        if name:find("^child%d+$") and val and not val.initialized then 
            SHG.Frames:NewUnitFrame(val) 
        end
    end)

    -- Apply to existing children (important for /reload)
    for _, child in ipairs({h:GetChildren()}) do
        if child:GetAttribute("unit") then SHG.Radial:RegisterButton(child) end
    end

    -- Apply initial bindings immediately
    local p = SHG:GetProfile()
    for key, action in pairs(p.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = (mod and mod ~= "") and (mod .. "-") or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        if actType and actVal then
            if actType == "radial" then
                -- Radial binding sa registruje cez RegisterButton (SecureHandlerWrapScript) na každom child frame
                -- Tu len uložíme radialID aby ho NewUnitFrame mohol použiť
                h:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
            elseif actType == "action" then
                h:SetAttribute(prefix .. "type" .. btn:match("%d+"), "macro")
                local mText = ""
                if actVal == "target" then mText = "/run TargetUnit('mouseover')"
                elseif actVal == "focus" then mText = "/run FocusUnit('mouseover')"
                elseif actVal == "assist" then mText = "/run AssistUnit('mouseover')"
                elseif actVal == "menu" then mText = "/run FriendsFrame_ShowDropdown(UnitName('mouseover'), 1)" end
                h:SetAttribute(prefix .. "macrotext" .. btn:match("%d+"), mText)
            else
                h:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                h:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
            end
        end
    end

    -- Shift+RightClick pre priority je nastaveny na kazdom child frame v NewUnitFrame

    self.Header = h
    h:Show()
end

function SHG.Frames:TogglePriority(name)
    if not name or name == "" then return end
    SHG.DB.priorityUnits = SHG.DB.priorityUnits or {}
    local found = false
    for i, n in ipairs(SHG.DB.priorityUnits) do
        if n == name then
            table.remove(SHG.DB.priorityUnits, i)
            found = true; break
        end
    end
    if not found then table.insert(SHG.DB.priorityUnits, name) end
    if SHG.Config and SHG.Config.UpdatePList then SHG.Config:UpdatePList() end
    -- Immediately update all visuals to reflect priority changes
    if self.Header then
        for _, child in ipairs({self.Header:GetChildren()}) do
            if child:GetAttribute("unit") then self:UpdateUnit(child, child:GetAttribute("unit")) end
        end
    end
    print(SHG.Title .. ": Priority toggle for |cffffffff" .. name .. "|r (" .. (found and "Removed" or "Added") .. ")")
end

function SHG.Frames:UpdateRoster()
    if InCombatLockdown() then return end
    if not self.Header then self:InitHeader() end
    
    local inR = GetNumRaidMembers() > 0
    local inP = GetNumPartyMembers() > 0
    
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
                    self.Header:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
                    self.Header:SetAttribute(prefix .. "type" .. btn:match("%d+"), nil)
                elseif actType == "action" then
                    -- Prekladame action:X na spravny WoW secure typ
                    local btnNum = btn:match("%d+")
                    if actVal == "target" then self.Header:SetAttribute(prefix .. "type" .. btnNum, "target")
                    elseif actVal == "focus" then self.Header:SetAttribute(prefix .. "type" .. btnNum, "focus")
                    elseif actVal == "assist" then self.Header:SetAttribute(prefix .. "type" .. btnNum, "assist")
                    elseif actVal == "menu" then self.Header:SetAttribute(prefix .. "type" .. btnNum, "togglemenu")
                    -- priority sa rieši cez OnMouseDown hook, nie secure attr
                    end
                else
                    self.Header:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                    self.Header:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
                    self.Header:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), nil)
                end
            end
        end
        
        -- Aktuálne vygenerované freamy preiterujeme a nastavíme správne
        local children = { self.Header:GetChildren() }
        for _, child in ipairs(children) do
            if child:IsProtected() and child:GetAttribute("unit") then
                -- Ochrana: Prvotné framy vygenerované pri SetAttribute.
                if not child.initialized then SHG.Frames:NewUnitFrame(child) end
                
                for key, action in pairs(p.bindings) do
                    local mod, btn = key:match("^(.-)%-?(type%d+)$")
                    if not btn then btn = key end
                    local prefix = mod and mod ~= "" and mod .. "-" or ""
                    local actType, actVal = action:match("^(.-):(.+)$")
                    if btn and actType and actVal then
                        if actType == "radial" then
                            -- Registration already handled on Header layer
                            child:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
                            child:SetAttribute(prefix .. "type" .. btn:match("%d+"), nil)
                        elseif actType == "action" then
                            -- Prekladame action:X na spravny WoW secure typ pre child frame
                            local btnNum = btn:match("%d+")
                            if actVal == "target" then child:SetAttribute(prefix .. "type" .. btnNum, "target")
                            elseif actVal == "focus" then child:SetAttribute(prefix .. "type" .. btnNum, "focus")
                            elseif actVal == "assist" then child:SetAttribute(prefix .. "type" .. btnNum, "assist")
                            elseif actVal == "menu" then child:SetAttribute(prefix .. "type" .. btnNum, "togglemenu")
                            -- priority sa riesi cez OnMouseDown hook
                            end
                        else
                            child:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                            child:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
                            child:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), nil)
                        end
                    end
                end
            end
        end
    end

    self.Header:Hide()
    
    if inR then
        self.Header:SetAttribute("showRaid", true)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", false)
    elseif inP then
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", true)
        self.Header:SetAttribute("showSolo", false)
    else
        self.Header:SetAttribute("showRaid", false)
        self.Header:SetAttribute("showParty", false)
        self.Header:SetAttribute("showSolo", true)
    end
    
    self.Header:SetAttribute("groupFilter", "1,2,3,4,5,6,7,8")
    self.Header:Show()
end

function SHG.Frames:UpdateVisuals()
    if InCombatLockdown() or not self.Header then return end
    
    local v = SHG:GetVisuals()
    local w, hDim = v.frameWidth, v.frameHeight
    self.Header:SetAttribute("initial-width", tostring(w))
    self.Header:SetAttribute("initial-height", tostring(hDim))
    self.Header:SetAttribute("unitsPerColumn", v.unitsPerColumn or 5)
    self.Header:SetAttribute("maxColumns", v.maxColumns or 8)

    -- Sorting and Grouping
    self.Header:SetAttribute("groupBy", "GROUP")
    self.Header:SetAttribute("groupingOrder", "1,2,3,4,5,6,7,8")
    self.Header:SetAttribute("sortMethod", "INDEX")
    
    local layout = SHG.DB.layoutMode or "Column"
    if layout == "Row" then
        self.Header:SetAttribute("point", "LEFT")
        self.Header:SetAttribute("columnAnchorPoint", "TOP")
        self.Header:SetAttribute("xOffset", v.xOffset or 6)
        self.Header:SetAttribute("yOffset", 0)
    else
        self.Header:SetAttribute("point", "TOP")
        self.Header:SetAttribute("columnAnchorPoint", "LEFT")
        self.Header:SetAttribute("xOffset", 0)
        self.Header:SetAttribute("yOffset", v.yOffset or -6)
    end
    
    self.Header:SetAttribute("columnSpacing", v.columnSpacing or 6)
    self.Header:SetScale(v.gridScale or 1.0)
    self.Header:SetAttribute("initialConfigFunction", string.format([[
        self:SetWidth(%d)
        self:SetHeight(%d)
        self:RegisterForClicks("AnyDown")
    ]], w, hDim))
    
    for _, child in ipairs({self.Header:GetChildren()}) do
        if child:IsProtected() and child:GetAttribute("unit") then
            child:RegisterForClicks("AnyDown")
            child:SetSize(w, hDim)
            child:SetBackdrop(self:GetBackdrop())
            child:SetBackdropColor(0, 0, 0, 0)
            child:SetBackdropBorderColor(0, 0.7, 1, 1)
            
            local barH = hDim - POWER_BAR_HEIGHT - 4
            if not SHG.DB.showMana then barH = hDim - 4 end
            
            if child.HealthBar then child.HealthBar:SetSize(w-4, barH) end
            if child.PowerBar then 
                child.PowerBar:SetSize(w-4, POWER_BAR_HEIGHT)
                if SHG.DB.showMana then child.PowerBar:Show() else child.PowerBar:Hide() end
            end
            
            if child.Name then
                child.Name:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], v.nameFontSize or 10, "OUTLINE")
            end
        end
    end

    -- Update Test Grid if active
    if self.testMode and self.testMode > 0 then
        self:ToggleTestMode(self.testMode)
    end
    
    -- Force Group Header Relayout
    self.Header:Hide()
    self.Header:Show()
end

function SHG.Frames:NewUnitFrame(f)
    f.initialized = true
    f:RegisterForClicks("AnyDown")
    
    SHG.Radial:RegisterButton(f)
    
    local w, h = GetDimensions()
    f:SetSize(w, h)
    f:SetBackdrop(self:GetBackdrop())
    f:SetBackdropColor(0, 0, 0, 0); f:SetBackdropBorderColor(0, 0.7, 1, 1)
    
    local barH = h - POWER_BAR_HEIGHT - 4
    if not SHG.DB.showMana then barH = h - 4 end
    
    local hp = CreateFrame("StatusBar", nil, f); hp:SetSize(w-4, barH); hp:SetPoint("TOP", 0, -2)
    hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.HealthBar = hp
    
    local pr = CreateFrame("StatusBar", nil, hp); pr:SetAllPoints(hp); pr:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    pr:SetStatusBarColor(0, 1, 0, 0.3); pr:SetFrameLevel(hp:GetFrameLevel()-1); f.PredictBar = pr
    
    local pw = CreateFrame("StatusBar", nil, f); pw:SetSize(w-4, POWER_BAR_HEIGHT); pw:SetPoint("BOTTOM", 0, 2)
    pw:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill"); f.PowerBar = pw
    
    local tf = CreateFrame("Frame", nil, f)
    tf:SetAllPoints(hp)
    tf:SetFrameLevel(hp:GetFrameLevel() + 5)
    f.TextFrame = tf
    
    local n = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    n:SetPoint("CENTER", tf, "CENTER")
    n:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], 10, "OUTLINE")
    f.Name = n
    
    f.Indicators = {}
    f.IndicatorStacks = {}
    f.IndicatorTimers = {}
    for _, p in ipairs({"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}) do
        local i = hp:CreateTexture(nil, "OVERLAY"); i:SetSize(12, 12)
        i:SetPoint(p, hp, p, p:find("LEFT") and 1 or -1, p:find("TOP") and -1 or 1)
        i:SetTexture("Interface\\Buttons\\WHITE8X8"); i:Hide(); f.Indicators[p] = i
        
        local s = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        s:SetPoint("CENTER", i, "CENTER", 0, 0)
        s:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        s:SetTextColor(1, 1, 1); s:Hide()
        f.IndicatorStacks[p] = s
        
        local timer = tf:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        -- Position timer beside the indicator (Left/Right depending on side)
        local anchorPoint = p:find("LEFT") and "LEFT" or "RIGHT"
        local xOff = p:find("LEFT") and 14 or -14
        timer:SetPoint("CENTER", i, "CENTER", xOff, 0)
        timer:SetFont("Fonts\\FRIZQT__.TTF", 8, "OUTLINE")
        timer:SetTextColor(1, 0.8, 0); timer:Hide()
        f.IndicatorTimers[p] = timer
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

    -- Raid Debuffs Container (Bottom)
    local rd = CreateFrame("Frame", nil, hp)
    rd:SetSize(w-10, 16); rd:SetPoint("BOTTOM", hp, "BOTTOM", 0, 2)
    f.RaidDebuffs = rd
    f.RaidDebuffIcons = {}
    for i=1, 3 do
        local icon = rd:CreateTexture(nil, "OVERLAY")
        icon:SetSize(14, 14); icon:SetPoint("LEFT", (i-1)*16, 0)
        icon:Hide(); f.RaidDebuffIcons[i] = icon
    end
    
    local th = CreateFrame("Frame", nil, f)
    th:SetAllPoints(f); th:SetFrameLevel(f:GetFrameLevel() + 5)
    th:SetBackdrop({edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14})
    th:SetBackdropBorderColor(1, 1, 1, 1); th:Hide(); f.TargetHighlight = th

    -- Rohove markery pre prioritnych hracov (zlata farba, L-shape)
    f.PriorityCorners = {}
    local cornerDefs = {
        { anchor = "TOPLEFT",     hx = 0,  hy = 0,  vx = 0,  vy = 0  },
        { anchor = "TOPRIGHT",    hx = 0,  hy = 0,  vx = 0,  vy = 0  },
        { anchor = "BOTTOMLEFT",  hx = 0,  hy = 0,  vx = 0,  vy = 0  },
        { anchor = "BOTTOMRIGHT", hx = 0,  hy = 0,  vx = 0,  vy = 0  },
    }
    local cSize = 6  -- dlzka ramena rohov v pixeloch
    local cThick = 2 -- hrubka ciary
    for _, cd in ipairs(cornerDefs) do
        local a = cd.anchor
        local xSign = a:find("LEFT") and 1 or -1
        local ySign = a:find("TOP") and -1 or 1
        -- Horizontalna cast
        local hLine = f:CreateTexture(nil, "OVERLAY")
        hLine:SetTexture("Interface\\Buttons\\WHITE8X8")
        hLine:SetVertexColor(1, 0.8, 0, 1)
        hLine:SetSize(cSize, cThick)
        hLine:SetPoint(a, f, a, xSign > 0 and 1 or -1, ySign < 0 and -1 or 1)
        hLine:Hide()
        -- Vertikalna cast
        local vLine = f:CreateTexture(nil, "OVERLAY")
        vLine:SetTexture("Interface\\Buttons\\WHITE8X8")
        vLine:SetVertexColor(1, 0.8, 0, 1)
        vLine:SetSize(cThick, cSize)
        vLine:SetPoint(a, f, a, xSign > 0 and 1 or -1, ySign < 0 and -1 or 1)
        vLine:Hide()
        f.PriorityCorners[a] = { hLine, vLine }
    end
    
    f:SetScript("OnEvent", function(self, ev, arg)
        local u = self:GetAttribute("unit")
        if ev == "PLAYER_TARGET_CHANGED" then
            if SHG.DB.showTargetHighlight and u and UnitIsUnit(u, "target") then self.TargetHighlight:Show() else self.TargetHighlight:Hide() end
            return
        end
        if not u or (arg and arg ~= u) then return end
        if ev == "UNIT_THREAT_SITUATION_UPDATE" then SHG.Frames:UpdateThreat(self, u); return end
        if ev:find("AURA") then SHG.Frames:UpdateAuras(self, u) else SHG.Frames:UpdateUnit(self, u) end
    end)
    f:RegisterEvent("UNIT_HEALTH"); f:RegisterEvent("UNIT_MAXHEALTH"); f:RegisterEvent("UNIT_POWER")
    f:RegisterEvent("UNIT_MAXPOWER"); f:RegisterEvent("UNIT_AURA"); f:RegisterEvent("UNIT_CONNECTION")
    f:RegisterEvent("PLAYER_TARGET_CHANGED"); f:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
    
    f:HookScript("OnAttributeChanged", function(self, attr, val)
        if attr == "unit" and val then
            SHG.Frames:UpdateUnit(self, val); SHG.Frames:UpdateAuras(self, val)
        end
    end)
    
    -- Aplikovanie bindings priamo na frame, aby click-casting fungoval 100%
    f:RegisterForClicks("AnyDown", "AnyUp")
    local p = SHG:GetProfile()
    for key, action in pairs(p.bindings) do
        local mod, btn = key:match("^(.-)%-?(type%d+)$")
        if not btn then btn = key end
        local prefix = mod and mod ~= "" and mod .. "-" or ""
        local actType, actVal = action:match("^(.-):(.+)$")
        if btn and actType and actVal then
            if actType == "radial" then
                -- Registration already handled on Header layer
                f:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), actVal)
                f:SetAttribute(prefix .. "type" .. btn:match("%d+"), nil)
            elseif actType == "action" then
                local btnNum = btn:match("%d+")
                if actVal == "target" then
                    f:SetAttribute(prefix .. "type" .. btnNum, "target")
                elseif actVal == "focus" then
                    f:SetAttribute(prefix .. "type" .. btnNum, "focus")
                elseif actVal == "assist" then
                    f:SetAttribute(prefix .. "type" .. btnNum, "assist")
                elseif actVal == "menu" then
                    f:SetAttribute(prefix .. "type" .. btnNum, "togglemenu")
                elseif actVal == "priority" then
                    f.priorityBind = f.priorityBind or {}
                    f.priorityBind[prefix .. btnNum] = true
                end
            else
                f:SetAttribute(prefix .. "type" .. btn:match("%d+"), actType)
                f:SetAttribute(prefix .. actType .. btn:match("%d+"), actVal)
                f:SetAttribute(prefix .. "radialID" .. btn:match("%d+"), nil)
            end
        end
    end

    -- Hook pre čistenie modrého kurzora pri zlyhaní kúzla
    f:HookScript("OnMouseUp", function() SpellStopTargeting() end)

    -- Priority Toggle: insecure OnMouseDown (nevolá protected API)
    f:HookScript("OnMouseDown", function(self, button)
        local pb = self.priorityBind
        if not pb or not button then return end
        local mod = ""
        if IsShiftKeyDown() and IsControlKeyDown() and IsAltKeyDown() then mod = "alt-ctrl-shift-"
        elseif IsShiftKeyDown() and IsControlKeyDown() then mod = "ctrl-shift-"
        elseif IsShiftKeyDown() and IsAltKeyDown() then mod = "alt-shift-"
        elseif IsControlKeyDown() and IsAltKeyDown() then mod = "alt-ctrl-"
        elseif IsShiftKeyDown() then mod = "shift-"
        elseif IsControlKeyDown() then mod = "ctrl-"
        elseif IsAltKeyDown() then mod = "alt-" end
        local btnNum = button == "LeftButton" and "1" or
                       button == "RightButton" and "2" or
                       button == "MiddleButton" and "3" or
                       button == "Button4" and "4" or
                       button == "Button5" and "5" or nil
        if not btnNum then return end
        if pb[mod .. btnNum] then
            local u = self:GetAttribute("unit")
            if u and UnitExists(u) then
                SHG.Frames:TogglePriority(UnitName(u))
            end
        end
    end)
    
    f:SetScript("OnUpdate", function(self, el)
        self.t = (self.t or 0) + el
        if self.t >= 0.2 then
            self.t = 0; local u = self:GetAttribute("unit")
            if u and LibRangeCheck then 
                local _, m = LibRangeCheck:GetRange(u)
                self.rangeAlpha = (m and m > 40) and 0.5 or 1.0
            else
                self.rangeAlpha = 1.0
            end
            SHG.Frames:UpdateUnit(self, u)
            SHG.Frames:UpdateHeals(self, u)
            SHG.Frames:UpdateAuraTimers(self, u)
            -- Only run global analysis from one frame to save CPU
            if SHG.DB.showClusters and self:GetName():find("1") then
                SHG.Frames:RunClusterAnalysis()
            end
        end
    end)
    local u = f:GetAttribute("unit"); if u then SHG.Frames:UpdateUnit(f, u); SHG.Frames:UpdateAuras(f, u) end
end

function SHG.Frames:RunClusterAnalysis()
    if not SHG.DB.showClusters then return end
    
    local units = {}
    if GetNumRaidMembers() > 0 then
        for i=1, GetNumRaidMembers() do table.insert(units, "raid"..i) end
    else
        table.insert(units, "player")
        for i=1, GetNumPartyMembers() do table.insert(units, "party"..i) end
    end

    local bestUnit = nil
    local maxHits = 0
    local frameMap = {}

    if self.Header then
        for _, child in ipairs({self.Header:GetChildren()}) do
            local u = child:GetAttribute("unit")
            if u then frameMap[u] = child end
        end
    end

    for _, u1 in ipairs(units) do
        if UnitExists(u1) and not UnitIsDeadOrGhost(u1) then
            local hits = 0
            -- Simplified evaluation: sum of missing HP of group members
            -- In real raid, WG hits group members mostly.
            -- We simulate 'cluster' by looking at health for now
            if (UnitHealth(u1) / UnitHealthMax(u1)) < 0.9 then hits = 1 end

            if hits > maxHits then
                maxHits = hits
                bestUnit = u1
            end
        end
    end

    for u, f in pairs(frameMap) do
        if u == bestUnit and maxHits > 0 then
            if not f.ClusterGlow then
                f.ClusterGlow = f:CreateTexture(nil, "OVERLAY")
                f.ClusterGlow:SetTexture("Interface\\Buttons\\CheckButtonHilight")
                f.ClusterGlow:SetBlendMode("ADD")
                f.ClusterGlow:SetAllPoints(f)
            end
            f.ClusterGlow:SetVertexColor(0, 1, 1, 0.4)
            f.ClusterGlow:Show()
        elseif f.ClusterGlow then
            f.ClusterGlow:Hide()
        end
    end
end

function SHG.Frames:UpdateAuras(f, u)
    if not UnitExists(u) then return end
    
    -- 1. Corners: Tracked Class Buffs (HoTs)
    local _, pCl = UnitClass("player")
    local classBuffs = SHG.DB.trackedBuffs and SHG.DB.trackedBuffs[pCl] or {}
    local corners = {"TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT"}
    
    for i, spellID in ipairs(classBuffs) do
        if i > 4 then break end
        local name = GetSpellInfo(spellID)
        local _, _, icon, count, _, duration, expiration = UnitBuff(u, name)
        local pos = corners[i]
        local indicator = f.Indicators[pos]
        local stackText = f.IndicatorStacks[pos]
        
        f.AuraExpiry = f.AuraExpiry or {}
        
        if icon then
            indicator:SetTexture(icon)
            indicator:Show()
            f.AuraExpiry[pos] = expiration
            if count and count > 1 then
                stackText:SetText(count)
                stackText:Show()
            else
                stackText:Hide()
            end
        else
            indicator:Hide()
            stackText:Hide()
            f.AuraExpiry[pos] = 0
        end
    end

    -- 2. Center: Dispellable Debuffs
    local hasDispel = false
    if SHG.DB.showDispels then
        for i = 1, 40 do
            local name, _, icon, count, debuffType = UnitDebuff(u, i)
            if not name then break end
            if debuffType and DispelTypes[debuffType] then
                f.DispelFrame.texture:SetTexture(icon)
                f.DispelFrame.index = i; f.DispelFrame:Show()
                local c = DispelColors[debuffType]
                f.HealthBar:SetStatusBarColor(c[1], c[2], c[3], 1)
                hasDispel = true; break
            end
        end
    end
    if not hasDispel then
        f.DispelFrame:Hide()
        f.HealthBar:SetStatusBarColor(self:GetHealthColor(u))
    end

    -- 3. Bottom: Tracked Raid Debuffs
    for i=1, 3 do f.RaidDebuffIcons[i]:Hide() end
    local rdIdx = 1
    if SHG.DB.trackedDebuffs then
        for i, debuffName in ipairs(SHG.DB.trackedDebuffs) do
            if rdIdx > 3 then break end
            local name, _, icon = UnitDebuff(u, debuffName)
            if icon then
                f.RaidDebuffIcons[rdIdx]:SetTexture(icon)
                f.RaidDebuffIcons[rdIdx]:Show()
                rdIdx = rdIdx + 1
            end
        end
    end
end

function SHG.Frames:UpdateThreat(f, u, targetAlpha)
    if not UnitExists(u) then return end
    targetAlpha = targetAlpha or 1.0

    local status = UnitThreatSituation(u)
    local bc = SHG.DB.borderColor or {r=0, g=0.7, b=1}

    -- Cerveny border iba pri plnom agre (status 3 = hrac ma highest threat na moby)
    -- Ide o indikaciu "tento hrac dostane incoming dmg"
    if SHG.DB.aggroHighlight and status and status == 3 then
        f:SetBackdropBorderColor(1, 0, 0, 1)
    else
        f:SetBackdropBorderColor(bc.r, bc.g, bc.b, targetAlpha)
    end
end

function SHG.Frames:UpdateUnit(f, u)
    if not UnitExists(u) then return end
    f:RegisterForClicks("AnyDown")
    
    if SHG.DB.showTargetHighlight and UnitIsUnit(u, "target") then f.TargetHighlight:Show() else f.TargetHighlight:Hide() end
    
    local cur, max = UnitHealth(u), UnitHealthMax(u)
    f.HealthBar:SetMinMaxValues(0, max); f.HealthBar:SetValue(cur)
    
    local txt = SHG.Utils.GetUnitStatus(u)
    if not txt then
        local nameStr = UnitName(u)
        if SHG.DB.hpTextMode == "Deficit" and cur < max then txt = nameStr .. "\n-" .. (max - cur)
        elseif SHG.DB.hpTextMode == "Percent" and max > 0 then txt = nameStr .. "\n" .. math.floor((cur/max)*100) .. "%"
        elseif SHG.DB.hpTextMode == "Current/Max" then txt = nameStr .. "\n" .. cur .. "/" .. max
        elseif SHG.DB.hpTextMode == "Current" then txt = nameStr .. "\n" .. cur
        else txt = nameStr end
    end
    f.Name:SetText(txt)
    f.Name:SetTextColor(self:GetNameColor(u))
    f.Name:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], SHG.DB.nameFontSize or 10, "OUTLINE")
    
    local w, h = GetDimensions()
    f:SetBackdrop(self:GetBackdrop())
    
    local bgC = SHG.DB.missingHpColor or {r=0.1, g=0.1, b=0.1}
    f:SetBackdropColor(bgC.r, bgC.g, bgC.b, 0.9)
    
    local pType = UnitPowerType(u)
    local canShowPower = false
    if pType == 0 and SHG.DB.showMana then canShowPower = true
    elseif pType == 1 and SHG.DB.showRage then canShowPower = true
    elseif pType == 3 and SHG.DB.showEnergy then canShowPower = true
    elseif pType == 6 and SHG.DB.showRunicPower then canShowPower = true end
    
    if canShowPower then
        f.HealthBar:SetHeight(h - POWER_BAR_HEIGHT - 4)
        f.PowerBar:SetSize(w - 4, POWER_BAR_HEIGHT)
        f.PowerBar:SetMinMaxValues(0, UnitPowerMax(u)); f.PowerBar:SetValue(UnitPower(u))
        local c = PowerBarColor[pType] or {r=0, g=0.5, b=1}; f.PowerBar:SetStatusBarColor(c.r, c.g, c.b); f.PowerBar:Show()
    else 
        f.HealthBar:SetHeight(h - 4)
        if f.PowerBar then f.PowerBar:Hide() end
    end
    
    -- Alpha Logic (Fading)
    local v = SHG:GetVisuals()
    local targetAlpha = f.rangeAlpha or 1.0
    local p = (max > 0) and (cur / max * 100) or 100
    -- Priority Check
    local unitName = UnitName(u)
    local isPriority = false
    if unitName and SHG.DB.priorityUnits then
        for _, name in pairs(SHG.DB.priorityUnits) do
            if name == unitName then isPriority = true; break end
        end
    end

    -- logic: priority units NEVER FADE
    local fadeM = v.fadeAlpha or 0.3
    if isPriority then
        targetAlpha = 1.0
    elseif SHG.DB.fullHpFade and SHG.DB.aggroFade then
        if shouldFadeHP and shouldFadeAggro then targetAlpha = targetAlpha * fadeM end
    elseif SHG.DB.fullHpFade then
        if shouldFadeHP then targetAlpha = targetAlpha * fadeM end
    elseif SHG.DB.aggroFade then
        if shouldFadeAggro then targetAlpha = targetAlpha * fadeM end
    end
    
    -- We apply alpha to the HealthBar and PowerBar, but NOT to the Name
    f.HealthBar:SetAlpha(targetAlpha)
    if f.PowerBar then f.PowerBar:SetAlpha(targetAlpha) end
    
    -- Name is ALWAYS fully visible
    if f.TextFrame then f.TextFrame:SetAlpha(1.0) end
    f.Name:SetAlpha(1.0)
    
    -- Root frame alpha stays 1.0 so Name doesn't fade
    f:SetAlpha(1.0)
    
    -- Backdrop is transparent for professional look (requested: background daj prec)
    f:SetBackdropColor(0, 0, 0, 0)
    local bc = SHG.DB.borderColor or {r=0, g=0.7, b=1}
    
    self:UpdateThreat(f, u, targetAlpha) 
    
    -- Rohove priority markery (zobrazia sa az po UpdateThreat, neprepisu agro border)
    if f.PriorityCorners then
        for _, lines in pairs(f.PriorityCorners) do
            if isPriority then lines[1]:Show(); lines[2]:Show()
            else lines[1]:Hide(); lines[2]:Hide() end
        end
    end
    
    -- Prioritny border uz nezlatiet backdrop - rohy to robia vizualne lepšie
    if not isPriority then
        f:GetParent():SetFrameLevel(1)
    else
        f:GetParent():SetFrameLevel(20)
    end 
    
    -- Aura indicators STAY full bright 1.0 alpha always (crucial for dispel/hots)
    for _, ind in pairs(f.Indicators) do ind:SetAlpha(1.0) end
    if f.DispelFrame then f.DispelFrame:SetAlpha(1.0) end
    
    self:UpdateAuras(f, u)
end

function SHG.Frames:UpdateAuraTimers(f, u)
    if not f.AuraExpiry then return end
    local now = GetTime()
    for pos, expiry in pairs(f.AuraExpiry) do
        local indicator = f.Indicators[pos]
        local stackText = f.IndicatorStacks[pos]
        local timerText = f.IndicatorTimers[pos]
        
        if indicator:IsShown() and expiry > 0 then
            local timeLeft = expiry - now
            if timeLeft > 0 then
                -- Show Timer only when < 5 seconds
                if timeLeft <= 5.1 then
                    timerText:SetText(math.ceil(timeLeft))
                    timerText:Show()
                else
                    timerText:Hide()
                end
                
                -- Pulsating Logic when < 3 seconds
                if timeLeft <= 3.2 then
                    local alpha = 0.3 + (math.sin(now * 15) + 1) * 0.35
                    indicator:SetAlpha(alpha)
                    indicator:SetVertexColor(1, 0.2, 0.2) -- Red Tint
                    timerText:SetAlpha(alpha)
                    timerText:SetTextColor(1, 0, 0) -- Timer Red
                    stackText:SetAlpha(alpha) -- Stacks also pulsate!
                else
                    indicator:SetAlpha(1.0)
                    indicator:SetVertexColor(1, 1, 1) -- Normal
                    timerText:SetAlpha(1.0)
                    timerText:SetTextColor(1, 1, 1)
                    stackText:SetAlpha(1.0)
                end
                
                -- Stacks always shown for context
                if stackText:GetText() ~= "" and tonumber(stackText:GetText() or 0) > 1 then 
                    stackText:Show() 
                end
            else
                timerText:Hide()
                indicator:SetAlpha(1.0)
                indicator:SetVertexColor(1, 1, 1)
            end
        else
            timerText:Hide()
        end
    end
end

function SHG.Frames:UpdateHeals(f, u)
    if LibHealComm and SHG.DB.showIncomingHeals then
        local inc = LibHealComm:GetHealAmount(u, LibHealComm.ALL_HEALS) or 0
        if inc > 0 then f.PredictBar:SetMinMaxValues(0, UnitHealthMax(u)); f.PredictBar:SetValue(UnitHealth(u)+inc); f.PredictBar:Show(); return end
    end
    f.PredictBar:Hide()
end

local testUnits = {
    {n="Artheas", c="PALADIN"}, {n="Sylvanax", c="HUNTER"}, {n="Jaina", c="MAGE"}, {n="Thrall", c="SHAMAN"}, {n="Anduin", c="PRIEST"},
    {n="Malfurion", c="DRUID"}, {n="Illidan", c="WARRIOR"}, {n="Guldan", c="WARLOCK"}, {n="Valeera", c="ROGUE"}, {n="Arthas", c="DEATHKNIGHT"},
    {n="Uther", c="PALADIN"}, {n="Saurfang", c="WARRIOR"}, {n="Baine", c="WARRIOR"}, {n="Tyrande", c="PRIEST"}, {n="Maiev", c="ROGUE"},
    {n="Kaelthas", c="MAGE"}, {n="Magni", c="WARRIOR"}, {n="Muradin", c="WARRIOR"}, {n="Voljin", c="SHAMAN"}, {n="Lorthermar", c="HUNTER"},
    {n="Velen", c="PRIEST"}, {n="Khagar", c="MAGE"}, {n="Garrosh", c="WARRIOR"}, {n="Rexxar", c="HUNTER"}, {n="Chen", c="DRUID"}
}

function SHG.Frames:ToggleTestMode(mode)
    if self.TestFrames then for _, f in pairs(self.TestFrames) do f:Hide() end end
    
    if mode == 0 then -- OFF
        if self.Header and not InCombatLockdown() then self.Header:Show() end
        return
    end

    if not self.Header then self:InitHeader() end
    self.Header:Hide()
    
    local v = SHG:GetVisuals()
    local w, h = v.frameWidth, v.frameHeight
    local unitsPerCol = v.unitsPerColumn or 5
    local num = (mode == 1) and 5 or 25
    
    for i = 1, num do
        if not self.TestFrames then self.TestFrames = {} end
        local f = self.TestFrames[i]
        if not f then
            f = CreateFrame("Frame", nil, UIParent)
            f:SetBackdrop(self:GetBackdrop())
            local hp = CreateFrame("StatusBar", nil, f); hp:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
            hp:SetPoint("TOP", 0, -2)
            f.HealthBar = hp
            local n = hp:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); n:SetPoint("CENTER")
            f.Name = n
            local pw = CreateFrame("StatusBar", nil, f); pw:SetStatusBarTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
            pw:SetPoint("BOTTOM", 0, 2)
            f.PowerBar = pw
            self.TestFrames[i] = f
        end

        local unitData = testUnits[i] or {n="Unit "..i, c="WARRIOR"}
        -- Mock unit for color functions
        local mockUnit = "player" -- Used just for class/status logic if needed, but we use testData
        
        f:SetScale(v.gridScale or 1.0)
        f:SetSize(w, h)
        
        local col = math.floor((i-1)/unitsPerCol)
        local row = (i-1)%unitsPerCol
        local xOff = col * (w + (v.columnSpacing or 6))
        local yOff = row * (h + math.abs(v.yOffset or 6))
        f:SetPoint("TOPLEFT", self.Anchor, "BOTTOMLEFT", xOff, -5 - yOff)

        -- 1. Colors & Fading Simulation
        local hpColorR, hpColorG, hpColorB = SHG.Utils.GetClassColor(nil, unitData.c)
        if SHG.DB.frameColorMode == "Gradient" or SHG.DB.frameColorMode == "Custom" then
            -- We use GetHealthColor logic but with a fake 0.8 HP for test
            local full = (SHG.DB.frameCustomColor or {r=0,g=1,b=0})
            local low = (SHG.DB.frameCustomColorLow or {r=1,g=0,b=0})
            hpColorR, hpColorG, hpColorB = full.r, full.g, full.b
        end

        local targetAlpha = 1.0
        if SHG.DB.fullHpFade then targetAlpha = v.fadeAlpha or 0.3 end

        f.HealthBar:SetAlpha(targetAlpha)
        if f.PowerBar then f.PowerBar:SetAlpha(targetAlpha) end

        -- 2. HP Text Mode
        local txt = unitData.n
        if SHG.DB.hpTextMode == "Percent" then txt = txt .. "\n100%"
        elseif SHG.DB.hpTextMode == "Deficit" then txt = txt
        elseif SHG.DB.hpTextMode == "Current" then txt = txt .. "\n5432" end
        f.Name:SetText(txt)

        -- 3. Name Color & Font
        local nr, ng, nb = SHG.Utils.GetClassColor(nil, unitData.c)
        if SHG.DB.nameColorMode == "Custom" then
            local c = SHG.DB.nameCustomColor or {r=1, g=1, b=1}
            nr, ng, nb = c.r, c.g, c.b
        end
        f.Name:SetTextColor(nr, ng, nb)
        f.Name:SetFont(FontPaths[SHG.DB.fontName] or FontPaths["Friz Quadrata TT"], v.nameFontSize or 10, "OUTLINE")
        f.Name:SetAlpha(1.0)

        -- 4. Bars & Border
        local barH = h - (SHG.DB.showMana and (POWER_BAR_HEIGHT + 4) or 4)
        f.HealthBar:SetSize(w-4, barH)
        f.HealthBar:SetStatusBarColor(hpColorR, hpColorG, hpColorB)
        
        if SHG.DB.showMana then
            f.PowerBar:SetSize(w-4, POWER_BAR_HEIGHT)
            local pc = PowerBarColor[0] -- Default Blue
            f.PowerBar:SetStatusBarColor(pc.r, pc.g, pc.b)
            f.PowerBar:Show()
        else
            f.PowerBar:Hide()
        end
        
        f:SetBackdrop(self:GetBackdrop())
        local bc = SHG.DB.borderColor or {r=0, g=0.7, b=1}
        f:SetBackdropBorderColor(bc.r, bc.g, bc.b, targetAlpha) 
        f:SetBackdropColor(0,0,0,0)

        f:Show()
    end
end
