-- [[ SAUSAGEHEALGRID RADIAL ]]
local addonName, SHG = ...
SHG.Radial = {}
local RootFrame

-- [[ SECURE SNIPPETS ]]
-- Táto časť kódu beží v restricted prostredí Blizzardu a má prístup k SetAttribute, ale nie k bežnému Lua.
local PRE_CLICK_SNIPPET = [=[
    local radial = self:GetFrameRef("radial")
    if not radial then return end
    
    -- Zistíme, ktoré tlačidlo myši bolo stlačené (napr. "LeftButton" -> "1")
    local btnNum = button:match("%d+") or (button == "LeftButton" and "1") or (button == "RightButton" and "2") or (button == "MiddleButton" and "3")
    
    if down then
        radial:Show()
    else
        local selected = radial:GetAttribute("selectedSpell")
        if selected and selected ~= "None" then
            self:SetAttribute("type", "spell")
            self:SetAttribute("spell", selected)
        end
        radial:Hide()
    end
]=]

local function CreateRadial()
    if RootFrame then return RootFrame end
    
    -- RootFrame musí byť SecureHandlerStateTemplate, aby mohol bežať secure kód
    RootFrame = CreateFrame("Frame", "SHG_RadialMenu", UIParent, "SecureHandlerStateTemplate")
    RootFrame:SetSize(220, 220); RootFrame:SetFrameStrata("TOOLTIP"); RootFrame:Hide()
    
    local center = RootFrame:CreateTexture(nil, "OVERLAY")
    center:SetSize(32, 32); center:SetPoint("CENTER"); center:SetTexture("Interface\\BUTTONS\\UI-Quickslot2")
    
    SHG.Radial.slots = {}
    for i = 1, 8 do
        local slot = CreateFrame("Frame", nil, RootFrame)
        slot:SetSize(48, 48)
        slot.icon = slot:CreateTexture(nil, "ARTWORK"); slot.icon:SetAllPoints()
        slot.bg = slot:CreateTexture(nil, "BACKGROUND"); slot.bg:SetSize(64, 64); slot.bg:SetPoint("CENTER"); slot.bg:SetTexture("Interface\\BUTTONS\\UI-EmptySlot-White")
        slot.highlight = slot:CreateTexture(nil, "OVERLAY"); slot.highlight:SetAllPoints(); slot.highlight:SetTexture("Interface\\Buttons\\CheckButtonHilight"); slot.highlight:SetBlendMode("ADD"); slot.highlight:Hide()
        SHG.Radial.slots[i] = slot
    end

    -- Monitorovanie myši cez OnUpdate (Non-secure pre vizuál)
    RootFrame:SetScript("OnUpdate", function(self, elapsed)
        local ux, uy = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale()
        local cx, cy = self:GetCenter()
        if not cx or not cy then return end
        local dx, dy = (ux/scale - cx), (uy/scale - cy)
        local dist = math.sqrt(dx*dx + dy*dy)
        
        local selectedIdx = nil
        local numActive = SHG.Radial.numActive or 0
        if numActive > 0 and dist > 25 then
            local angle = math.deg(math.atan2(dy, dx))
            local menuAngle = (90 - angle) % 360
            local sliceWidth = 360 / numActive
            
            for i = 1, numActive do
                local slotAngle = (i-1) * sliceWidth
                local diff = math.abs(menuAngle - slotAngle)
                if diff > 180 then diff = 360 - diff end
                if diff < (sliceWidth / 2) then
                    selectedIdx = i
                    break
                end
            end
        end
        
        local selectedSpell = "None"
        for i = 1, 8 do
            local slot = SHG.Radial.slots[i]
            if i == selectedIdx then
                slot.highlight:Show(); slot:SetScale(1.2)
                selectedSpell = slot.spell
            else
                slot.highlight:Hide(); slot:SetScale(1.0)
            end
        end
        self:SetAttribute("selectedSpell", selectedSpell)
    end)
    
    return RootFrame
end

function SHG.Radial:Update(menuID)
    local menu = SHG.DB.radialMenus[menuID]
    if not menu then return end
    CreateRadial()
    local activeData = {}
    for i = 1, 8 do if menu[i] and menu[i].spell and menu[i].spell ~= "None" then tinsert(activeData, menu[i]) end end
    self.numActive = #activeData
    
    for i = 1, 8 do
        local slot = self.slots[i]
        if i <= self.numActive then
            local data = activeData[i]
            local angle = math.rad((i-1) * (360 / self.numActive) - 90)
            local x, y = math.cos(angle) * 85, math.sin(angle) * 85
            slot:ClearAllPoints(); slot:SetPoint("CENTER", RootFrame, "CENTER", x, y)
            slot.spell = data.spell
            local _, _, tex = GetSpellInfo(data.spell)
            slot.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
            slot:Show()
        else
            slot:Hide()
        end
    end
end

-- Registrácia tlačidla pre Radial Menu
function SHG.Radial:RegisterButton(btn)
    if not btn or btn.SHG_RadialRegistered then return end
    local f = CreateRadial()
    
    -- Prepojíme tlačidlo s Radial Menu pomocou SecureHandler-a
    SecureHandlerWrapScript(btn, "OnClick", btn, PRE_CLICK_SNIPPET)
    btn:SetFrameRef("radial", f)
    btn.SHG_RadialRegistered = true
end

-- Táto Show funkcia je tu už len pre ne-secure volania (napr. test)
function SHG.Radial:Show(unit, menuID)
    local f = CreateRadial()
    self:Update(menuID or 1)
    local ux, uy = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    f:ClearAllPoints(); f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", ux / scale, uy / scale)
    f:Show()
end
