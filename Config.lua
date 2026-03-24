-- [[ SAUSAGEHEALGRID CONFIG ]]
local addonName, SHG = ...
SHG.Config = {}
local MainFrame

local Fonts = { "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus" }
local HealthModes = { "Class", "Health" }
local NameColorModes = { "Class", "Custom" }
local BorderStyles = { "Blizzard Tooltip", "Solid", "None" }

-- Pomocná funkcia na získanie kúzla zo spellbooku
-- Pomocná funkcia na získanie kúzla zo spellbooku rozdeleného podľa kategórií
local function GetPlayerSpells()
    local categories = {}
    local numTabs = GetNumSpellTabs()
    for t = 1, numTabs do
        local tabName, _, offset, numSpells = GetSpellTabInfo(t)
        local spells = {}
        for i = offset + 1, offset + numSpells do
            local name = GetSpellName(i, BOOKTYPE_SPELL)
            if name and name ~= "" then
                -- Použijeme hash na unikátne kúzla (ignorujeme ranky pre zoznam)
                local found = false
                for _, s in ipairs(spells) do if s == name then found = true; break end end
                if not found then tinsert(spells, name) end
            end
        end
        table.sort(spells)
        if #spells > 0 then
            tinsert(categories, { name = tabName, spells = spells })
        end
    end
    -- Pridáme Radials ako špeciálnu kategóriu
    tinsert(categories, { name = "Radials", spells = { "Radial Menu 1" } })
    return categories
end

local function ShowColorPicker(r, g, b, callback)
    ColorPickerFrame.func = function()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        callback(nr, ng, nb)
    end
    ColorPickerFrame.hasOpacity = false
    ColorPickerFrame.cancelFunc = function(prev) callback(prev.r, prev.g, prev.b) end
    ColorPickerFrame:SetColorRGB(r, g, b)
    ColorPickerFrame.previousValues = {r = r, g = g, b = b}
    ColorPickerFrame:Hide(); ColorPickerFrame:Show()
end

local function CreateDropdown(parent, name, items, currentVal, callback, x, y, width)
    local dd = CreateFrame("Frame", name, parent, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", x, y)
    local function OnClick(self)
        UIDropDownMenu_SetSelectedID(dd, self:GetID(), UIDROPDOWNMENU_MENU_LEVEL)
        UIDropDownMenu_SetText(dd, self.value)
        callback(self.value)
        CloseDropDownMenus()
    end
    local function Initialize(self, level)
        level = level or 1
        local info = UIDropDownMenu_CreateInfo()
        if level == 1 then
            -- "None" option
            info.text = "None"; info.value = "None"; info.func = OnClick
            UIDropDownMenu_AddButton(info, level)
            
            -- Categories
            for _, cat in ipairs(items) do
                info = UIDropDownMenu_CreateInfo()
                info.text = cat.name; info.value = cat.name; info.hasArrow = true; info.notCheckable = true
                UIDropDownMenu_AddButton(info, level)
            end
        elseif level == 2 then
            local category = UIDROPDOWNMENU_MENU_VALUE
            for _, cat in ipairs(items) do
                if cat.name == category then
                    for _, spell in ipairs(cat.spells) do
                        info = UIDropDownMenu_CreateInfo()
                        info.text = spell; info.value = spell; info.func = OnClick
                        UIDropDownMenu_AddButton(info, level)
                    end
                    break
                end
            end
        end
    end
    UIDropDownMenu_Initialize(dd, Initialize)
    UIDropDownMenu_SetWidth(dd, width or 120)
    UIDropDownMenu_SetText(dd, currentVal or "None")
    return dd
end

function SHG.Config:Create()
    if MainFrame then return MainFrame end
    
    MainFrame = CreateFrame("Frame", "SHG_MainFrame", UIParent)
    MainFrame:SetSize(520, 660); MainFrame:SetPoint("CENTER")
    MainFrame:SetMovable(true); MainFrame:EnableMouse(true); MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving); MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    MainFrame:SetFrameStrata("HIGH")
    
    MainFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 14,
        insets = { left = 3, right = 3, top = 3, bottom = 3 }
    })
    MainFrame:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
    MainFrame:SetBackdropBorderColor(1, 0.6, 0, 1) -- Sausage Party Orange
    tinsert(UISpecialFrames, "SHG_MainFrame")

    local h = MainFrame:CreateTexture(nil, "OVERLAY")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); h:SetSize(300, 68); h:SetPoint("TOP", 0, 12)
    local titleText = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("TOP", h, "TOP", 0, -14); titleText:SetText(SHG.Title .. " Config")
    CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -8, -8)

    -- Tab System
    local tab1 = CreateFrame("Button", "SHG_MainFrameTab1", MainFrame, "CharacterFrameTabButtonTemplate")
    tab1:SetPoint("BOTTOMLEFT", 15, -28); tab1:SetText("General"); tab1:SetID(1); _G[tab1:GetName()] = tab1
    
    local tab2 = CreateFrame("Button", "SHG_MainFrameTab2", MainFrame, "CharacterFrameTabButtonTemplate")
    tab2:SetPoint("LEFT", tab1, "RIGHT", -15, 0); tab2:SetText("Display"); tab2:SetID(2); _G[tab2:GetName()] = tab2

    local tab3 = CreateFrame("Button", "SHG_MainFrameTab3", MainFrame, "CharacterFrameTabButtonTemplate")
    tab3:SetPoint("LEFT", tab2, "RIGHT", -15, 0); tab3:SetText("Spells & Binds"); tab3:SetID(3); _G[tab3:GetName()] = tab3
    
    local panels = {}
    for i = 1, 3 do
        panels[i] = CreateFrame("Frame", nil, MainFrame)
        panels[i]:SetPoint("TOPLEFT", 15, -45); panels[i]:SetPoint("BOTTOMRIGHT", -15, 45)
        panels[i]:Hide()
    end

    PanelTemplates_SetNumTabs(MainFrame, 3); PanelTemplates_SetTab(MainFrame, 1); panels[1]:Show()

    local function SwitchTab(id)
        PanelTemplates_SetTab(MainFrame, id)
        for i, p in ipairs(panels) do if i == id then p:Show() else p:Hide() end end
    end

    tab1:SetScript("OnClick", function() SwitchTab(1) end)
    tab2:SetScript("OnClick", function() SwitchTab(2) end)
    tab3:SetScript("OnClick", function() SwitchTab(3) end)

    -- PANEL 1: General
    local p1 = panels[1]; local y = -10
    local function AddCB1(txt, key)
        local cb = CreateFrame("CheckButton", nil, p1, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 15, y); cb:SetChecked(SHG.DB[key])
        cb:SetScript("OnClick", function(self) 
            SHG.DB[key] = self:GetChecked()
            if key == "locked" and SHG.Frames then SHG.Frames:UpdateAnchor() end
        end)
        local l = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("LEFT", cb, "RIGHT", 5, 0); l:SetText(txt)
        y = y - 32
    end
    AddCB1("Lock Frames (Hide Anchor)", "locked")
    AddCB1("Show Mana Bars", "showMana")
    AddCB1("Show Incoming Heals", "showIncomingHeals")
    AddCB1("Show Target Highlight", "showTargetHighlight")
    AddCB1("Show Dispels (Debuffs)", "showDispels")

    -- PANEL 2: Display
    local p2 = panels[2]; y = -10
    local function AddSlider2(txt, key, minVal, maxVal, step)
        local slider = CreateFrame("Slider", "SHG_Slider_"..key, p2, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 15, y); slider:SetWidth(180); slider:SetMinMaxValues(minVal, maxVal); slider:SetValueStep(step)
        slider:SetValue(SHG.DB[key] or minVal)
        _G[slider:GetName().."Text"]:SetText(txt .. ": " .. string.format("%.1f", SHG.DB[key] or minVal))
        slider:SetScript("OnValueChanged", function(self, value) SHG.DB[key] = value; _G[self:GetName().."Text"]:SetText(txt .. ": " .. string.format("%.1f", value)) end)
        y = y - 45
    end
    AddSlider2("Frame Width", "frameWidth", 40, 150, 1)
    AddSlider2("Frame Height", "frameHeight", 20, 100, 1)
    AddSlider2("Column Spacing", "columnSpacing", 0, 20, 1)
    AddSlider2("Row Offset (Y)", "yOffset", -30, 0, 1)
    
    y = y - 10
    local lFont = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lFont:SetPoint("TOPLEFT", 15, y); lFont:SetText("Font:")
    CreateDropdown(p2, "SHG_DD_F", Fonts, SHG.DB.fontName, function(v) SHG.DB.fontName = v end, 60, y+5, 120); y = y - 40
    
    local lBorder = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lBorder:SetPoint("TOPLEFT", 15, y); lBorder:SetText("Border:")
    CreateDropdown(p2, "SHG_DD_B", BorderStyles, SHG.DB.borderStyle, function(v) SHG.DB.borderStyle = v end, 100, y+5, 120); y = y - 40

    -- PANEL 3: Spells & Binds
    local p3 = panels[3]; y = -10
    local spells = GetPlayerSpells()
    local selectedMouseButton = 1
    local editingProfile = GetActiveTalentGroup() or 1

    local profHeader = p3:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profHeader:SetPoint("TOPLEFT", 10, y); profHeader:SetText("Select Profile to Edit:")
    y = y - 25

    local pButtons = {}
    for i = 1, 2 do
        local btn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
        btn:SetSize(140, 24); btn:SetPoint("TOPLEFT", 10 + (i-1)*150, y)
        btn:SetScript("OnClick", function() editingProfile = i; SHG.Config:UpdateSpellPanel() end)
        pButtons[i] = btn
    end
    y = y - 35

    local buttonLabels = { "Left Click", "Right Click", "Middle Click", "Mouse 4", "Mouse 5" }
    local mButtons = {}
    for i = 1, 5 do
        local btn = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
        btn:SetSize(90, 25); btn:SetText(buttonLabels[i])
        btn:SetPoint("TOPLEFT", 10 + (i-1)*95, y)
        btn:SetScript("OnClick", function() selectedMouseButton = i; SHG.Config:UpdateSpellPanel() end)
        mButtons[i] = btn
    end
    y = y - 45

    -- Configure Radial Button
    local confRadial = CreateFrame("Button", nil, p3, "UIPanelButtonTemplate")
    confRadial:SetSize(140, 25); confRadial:SetPoint("TOPLEFT", 350, -10); confRadial:SetText("Setup Radial Menu")
    confRadial:SetScript("OnClick", function() SHG.Config:ShowRadialConfig() end)

    local spellRows = CreateFrame("Frame", nil, p3)
    spellRows:SetPoint("TOPLEFT", 0, y); spellRows:SetPoint("BOTTOMRIGHT", 0, 0)

    function SHG.Config:UpdateSpellPanel()
        -- Update Profile Buttons
        local activeSpec = GetActiveTalentGroup() or 1
        for i = 1, 2 do
            local p = SHG.DB.profiles[i]
            local name = p and p.name or ("Spec "..i)
            local txt = name .. (i == activeSpec and " |cFF00FF00(ACTIVE)|r" or "")
            pButtons[i]:SetText(txt)
            if i == editingProfile then pButtons[i]:LockHighlight() else pButtons[i]:UnlockHighlight() end
        end

        -- Update Mouse Buttons
        for i, b in ipairs(mButtons) do if i == selectedMouseButton then b:LockHighlight() else b:UnlockHighlight() end end
        
        -- Rows
        self.rows = self.rows or {}
        local mods = { "", "shift-", "ctrl-", "alt-", "shift-ctrl-", "shift-alt-", "ctrl-alt-", "shift-ctrl-alt-" }
        local modLabels = { "None", "Shift", "Ctrl", "Alt", "Shift+Ctrl", "Shift+Alt", "Ctrl+Alt", "Shift+Ctrl+Alt" }
        
        local p = SHG.DB.profiles[editingProfile]
        if not p then return end

        for i, mod in ipairs(mods) do
            local row = self.rows[i]
            if not row then
                row = CreateFrame("Frame", nil, spellRows)
                row:SetSize(480, 40); row:SetPoint("TOPLEFT", 10, -(i-1)*40) -- Increased row height to 40
                local l = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
                l:SetPoint("LEFT", 5, 0); l:SetWidth(110); l:SetJustifyH("LEFT")
                row.label = l
                -- We create the dropdown only once per row
                row.dd = CreateDropdown(row, "SHG_SpellDD_"..i, spells, "None", function(v)
                    local key = row.currentKey
                    if v == "None" then p.bindings[key] = nil 
                    elseif v:find("Radial Menu") then
                        p.bindings[key] = "radial:" .. v:match("%d+")
                    else
                        p.bindings[key] = "spell:" .. v 
                    end
                end, 120, 12, 220) -- Positioned inside the row
                self.rows[i] = row
            end
            row.label:SetText(modLabels[i])
            local key = mod .. "type" .. selectedMouseButton
            row.currentKey = key
            local rawVal = p.bindings[key] or ""
            local currentVal = "None"
            if rawVal:find("^spell:") then currentVal = rawVal:gsub("^spell:", "")
            elseif rawVal:find("^radial:") then currentVal = "Radial Menu " .. rawVal:gsub("^radial:", "") end
            
            UIDropDownMenu_SetText(row.dd, currentVal)
            row:Show()
        end
    end

    function SHG.Config:ShowRadialConfig()
        if self.RadialPop then self.RadialPop:Show(); return end
        
        local pop = CreateFrame("Frame", "SHG_RadialConfig", MainFrame)
        pop:SetSize(350, 480); pop:SetPoint("CENTER")
        pop:SetFrameStrata("DIALOG")
        pop:SetToplevel(true) -- Aby sa okno dalo vytiahnuť do popredia
        pop:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        self.RadialPop = pop
        
        local scroll = CreateFrame("ScrollFrame", "SHG_RadialScrollFrame", pop, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 15, -45); scroll:SetPoint("BOTTOMRIGHT", -35, 45)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(300, 400); scroll:SetScrollChild(content)
        
        local l = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal"); l:SetPoint("TOP", 0, -15); l:SetText("Configure Radial Menu 1")
        CreateFrame("Button", nil, pop, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -8, -8)
        
        local spells = GetPlayerSpells()
        for i = 1, 8 do
            local sl = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sl:SetPoint("TOPLEFT", 10, -(i-1)*45); sl:SetText("Slot " .. i .. ":")
            local data = SHG.DB.radialMenus[1][i]
            CreateDropdown(content, "SHG_RadialSlotDD_"..i, spells, data.spell or "None", function(v)
                SHG.DB.radialMenus[1][i].spell = v
            end, 60, -(i-1)*45 + 5, 180)
        end
        
        pop:Show()
    end

    SHG.Config:UpdateSpellPanel()

    -- Footer
    local save = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    save:SetSize(130, 30); save:SetPoint("BOTTOMLEFT", 25, 15); save:SetText("Save & Reload")
    save:SetScript("OnClick", function() ReloadUI() end)

    MainFrame:Hide()
    return MainFrame
end

function SHG.Config:Toggle()
    local f = self:Create()
    if f:IsShown() then f:Hide() else f:Show() end
end
