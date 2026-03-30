-- [[ SAUSAGEHEALGRID RADIAL - Hold & Release system ]]
local addonName, SHG = ...
SHG.Radial = {}

local RootFrame
local MAX_MENUS = 3
local MAX_SLOTS = 8
local SLOT_RADIUS = 90

-- [[ BINDINGS ]]
_G.BINDING_HEADER_SAUSAGEHEALGRID = "SausageHealgrid"
for i = 1, MAX_MENUS do
    _G["BINDING_NAME_SHG_RADIAL_"..i] = "Radial Menu " .. i .. " (Hold & Release)"
end

-- ============================================================
-- [[ LOCAL STATE (non-secure) ]]
-- ============================================================
local hoveredUnit = nil      -- jednotka pod myšou
local activeMenuID = nil     -- aktuálne otvorené menu

-- ============================================================
-- [[ RADIAL FRAME CREATION ]]
-- ============================================================
local function GetOrCreateRadial()
    if RootFrame then return RootFrame end

    RootFrame = CreateFrame("Frame", "SHG_RadialMenu", UIParent)
    RootFrame:SetSize(220, 220)
    RootFrame:SetFrameStrata("TOOLTIP")
    RootFrame:SetPoint("CENTER")
    RootFrame:Hide()

    -- Vizuálne centrum
    local center = RootFrame:CreateTexture(nil, "OVERLAY")
    center:SetSize(32, 32)
    center:SetPoint("CENTER")
    center:SetTexture("Interface\\BUTTONS\\UI-Quickslot2")

    -- Vytvorenie slotov
    SHG.Radial.slots = {}
    for i = 1, MAX_SLOTS do
        local slot = CreateFrame("Button", "SHG_RadialSlot"..i, RootFrame, "SecureActionButtonTemplate")
        slot:SetSize(56, 56)
        slot:RegisterForClicks("AnyUp")

        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetSize(44, 44)
        slot.icon:SetPoint("CENTER")
        slot.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetSize(64, 64)
        slot.bg:SetPoint("CENTER")
        slot.bg:SetTexture("Interface\\BUTTONS\\UI-EmptySlot-White")

        slot.hl = slot:CreateTexture(nil, "OVERLAY")
        slot.hl:SetAllPoints()
        slot.hl:SetTexture("Interface\\Buttons\\CheckButtonHilight")
        slot.hl:SetBlendMode("ADD")
        slot.hl:Hide()

        -- Kliknutie na slot spustí kúzlo cez makro (zachová targeting) a zavrie menu
        slot:SetScript("OnClick", function(self, button)
            if self.spell and self.spell ~= "None" and hoveredUnit then
                RunMacroText("/cast [@" .. hoveredUnit .. "] " .. self.spell)
            end
            SHG.Radial:Close()
        end)

        SHG.Radial.slots[i] = slot
    end

    -- OnUpdate sleduje kurzor a highlightuje najbližší slot
    RootFrame:SetScript("OnUpdate", function(self, elapsed)
        if not RootFrame:IsShown() then return end
        local ux, uy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = self:GetCenter()
        if not cx or not cy then return end
        local dx, dy = (ux / scale - cx), (uy / scale - cy)
        local dist = math.sqrt(dx * dx + dy * dy)

        local numActive = SHG.Radial.numActive or 0
        local selectedIdx = nil
        if numActive > 0 and dist > 25 then
            local angle = math.deg(math.atan2(dy, dx))
            local menuAngle = (90 - angle) % 360
            local sliceWidth = 360 / numActive
            for i = 1, numActive do
                local slotAngle = (i - 1) * sliceWidth
                local diff = math.abs(menuAngle - slotAngle)
                if diff > 180 then diff = 360 - diff end
                if diff < (sliceWidth / 2) then
                    selectedIdx = i
                    break
                end
            end
        end

        SHG.Radial.selectedIdx = selectedIdx
        for i = 1, MAX_SLOTS do
            local slot = SHG.Radial.slots[i]
            if slot then
                if i == selectedIdx then
                    slot.hl:Show(); slot:SetScale(1.2)
                else
                    slot.hl:Hide(); slot:SetScale(1.0)
                end
            end
        end
    end)

    return RootFrame
end

-- ============================================================
-- [[ PUBLIC API ]]
-- ============================================================

function SHG.Radial:Open(menuID)
    if not hoveredUnit then return end
    activeMenuID = menuID or 1
    self:Update(activeMenuID)

    local ux, uy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    local f = GetOrCreateRadial()
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux / scale, uy / scale)
    f:Show()
end

function SHG.Radial:Close()
    if RootFrame then RootFrame:Hide() end
    -- Reset highlight
    for i = 1, MAX_SLOTS do
        local slot = self.slots and self.slots[i]
        if slot then slot.hl:Hide(); slot:SetScale(1.0) end
    end
    self.selectedIdx = nil
    activeMenuID = nil
end

function SHG.Radial:Release(menuID)
    -- Volaná pri pustení klávesy - zošle kúzlo cez makro (funguje mimo boja)
    local idx = self.selectedIdx
    if idx and hoveredUnit and UnitExists(hoveredUnit) then
        local slot = self.slots and self.slots[idx]
        if slot and slot.spell and slot.spell ~= "None" then
            RunMacroText("/cast [@" .. hoveredUnit .. "] " .. slot.spell)
        end
    end
    self:Close()
end

function SHG.Radial:Update(menuID)
    local menu = SHG.DB and SHG.DB.radialMenus and SHG.DB.radialMenus[menuID]
    if not menu then return end
    GetOrCreateRadial()

    local activeData = {}
    for i = 1, MAX_SLOTS do
        if menu[i] and menu[i].spell and menu[i].spell ~= "None" then
            tinsert(activeData, menu[i])
        end
    end
    self.numActive = #activeData

    for i = 1, MAX_SLOTS do
        local slot = self.slots[i]
        if i <= self.numActive then
            local data = activeData[i]
            -- Sloty idú CW od vrcholu, čo zodpovedá detekcii (menuAngle = 90 - atan2)
            local angle = math.rad(90 - (i - 1) * (360 / self.numActive))
            local x, y = math.cos(angle) * SLOT_RADIUS, math.sin(angle) * SLOT_RADIUS
            slot:ClearAllPoints()
            slot:SetPoint("CENTER", RootFrame, "CENTER", x, y)
            slot.spell = data.spell
            local _, _, tex = GetSpellInfo(data.spell)
            slot.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            slot:Show()
        else
            slot.spell = nil
            slot:Hide()
        end
    end
end

function SHG.Radial:UpdateAllMenus()
    if InCombatLockdown() then return end
    GetOrCreateRadial()
    for mID = 1, MAX_MENUS do
        self:Update(mID)
    end
end

-- ============================================================
-- [[ UNIT FRAME HOVER TRACKING ]]
-- ============================================================
function SHG.Radial:RegisterButton(btn)
    if not btn or btn.SHG_RadialRegistered then return end

    -- Sledovanie hovered unit (non-secure, len pre Open/Release)
    btn:HookScript("OnEnter", function(self)
        hoveredUnit = self:GetAttribute("unit")
    end)
    btn:HookScript("OnLeave", function(self)
        -- Ponecháme posledný hovered unit počas otvoreného menu
        if not (RootFrame and RootFrame:IsShown()) then
            hoveredUnit = nil
        end
    end)

    -- Otvorenie radiálneho menu pri kliknutí (click-binding flow z Config panelu)
    btn:HookScript("OnMouseDown", function(self, button)
        local btnNum = button == "LeftButton"   and "1" or
                       button == "RightButton"  and "2" or
                       button == "MiddleButton" and "3" or
                       button == "Button4"      and "4" or
                       button == "Button5"      and "5" or nil
        if not btnNum then return end

        -- Zostav modifier prefix zhodný s logikou bindingov
        local mod = ""
        if IsShiftKeyDown() and IsControlKeyDown() and IsAltKeyDown() then mod = "alt-ctrl-shift-"
        elseif IsShiftKeyDown() and IsControlKeyDown() then mod = "ctrl-shift-"
        elseif IsShiftKeyDown() and IsAltKeyDown()     then mod = "alt-shift-"
        elseif IsControlKeyDown() and IsAltKeyDown()   then mod = "alt-ctrl-"
        elseif IsShiftKeyDown()   then mod = "shift-"
        elseif IsControlKeyDown() then mod = "ctrl-"
        elseif IsAltKeyDown()     then mod = "alt-"
        end

        local radialID = self:GetAttribute(mod .. "radialID" .. btnNum)
        if radialID then
            SHG.Radial:Open(tonumber(radialID))
        end
    end)

    btn.SHG_RadialRegistered = true
end

-- ============================================================
-- [[ PROXY KEY HANDLERS ]]
-- Tieto framy zachytia stlačenie/pustenie klávesy (F, Mouse4...)
-- ============================================================
local function SetupProxies()
    for menuID = 1, MAX_MENUS do
        local proxy = CreateFrame("Button", "SHG_RadialProxy"..menuID, UIParent)
        proxy.menuID = menuID
        proxy:RegisterForClicks("AnyDown", "AnyUp")

        -- Stlačenie klávesu = otvor menu
        proxy:SetScript("OnMouseDown", function(self)
            SHG.Radial:Open(self.menuID)
        end)

        -- Pustenie klávesu = zoši kúzlo
        proxy:SetScript("OnMouseUp", function(self)
            SHG.Radial:Release(self.menuID)
        end)

        -- Naviazanie klávesovej skratky na kliknutie proxy tlačidla (neskráda focus)
        proxy:RegisterEvent("UPDATE_BINDINGS")
        proxy:RegisterEvent("PLAYER_LOGIN")
        proxy:SetScript("OnEvent", function(self)
            local k1, k2 = GetBindingKey("SHG_RADIAL_" .. self.menuID)
            if k1 then SetBindingClick(k1, self:GetName(), "LeftButton") end
            if k2 then SetBindingClick(k2, self:GetName(), "LeftButton") end
        end)
    end
end

-- Globálne funkcie pre klávesové skratky (ak by boli nastavené ako macro-style)
function SHG_OpenRadial(menuID)
    SHG.Radial:Open(menuID or 1)
end
function SHG_CloseRadial(menuID)
    SHG.Radial:Release(menuID or 1)
end

-- Hlavná inicializácia
SetupProxies()
