-- [[ SAUSAGEHEALGRID CONFIG ]]
local addonName, SHG = ...
SHG.Config = {}
local MainFrame

local Fonts = { 
    "Friz Quadrata TT", "Arial Narrow", "Morpheus",
    "Accidental Presidency", "Adventure", "Bangers", "Dosis", "Expressive",
    "Freedom", "Gothics", "Indie Flower", "Lato", "Luckiest Guy", "Montserrat"
}
local HealthModes = { "Class", "Gradient", "Custom" }
local NameColorModes = { "Class", "Custom" }
local BorderStyles = { "Blizzard Tooltip", "Solid", "None" }

-- Pomocná funkcia na získanie kúzla zo spellbooku
-- Pomocná funkcia na získanie kúzla zo spellbooku rozdeleného podľa kategórií
local function GetPlayerSpells()
    local categories = {}
    
    -- Raid Management category
    tinsert(categories, { 
        name = "Raid Management", 
        spells = { "Target", "Focus", "Assist", "Context Menu", "Toggle Priority" } 
    })

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
    -- Pridáme Radials ako špeciálnu kategóriu (1, 2, 3)
    tinsert(categories, { 
        name = "Radials", 
        spells = { "Radial Menu 1", "Radial Menu 2", "Radial Menu 3" } 
    })
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
    dd.callback = callback
    local function OnClick(self)
        UIDropDownMenu_SetSelectedID(dd, self:GetID(), UIDROPDOWNMENU_MENU_LEVEL)
        UIDropDownMenu_SetText(dd, self.value)
        if dd.callback then dd.callback(self.value) end
        CloseDropDownMenus()
    end
 local function Initialize(self, level)
        level = level or 1
        local info = UIDropDownMenu_CreateInfo()
        if level == 1 then
            -- "None" option (only for non-font items)
            if items ~= Fonts then
                info.text = "None"; info.value = "None"; info.func = OnClick
                UIDropDownMenu_AddButton(info, level)
            end
            
            -- Categories
            for _, cat in ipairs(items) do
                info = UIDropDownMenu_CreateInfo()
                if type(cat) == "table" and cat.name then
                    info.text = cat.name; info.value = cat.name; info.hasArrow = true; info.notCheckable = true
                    UIDropDownMenu_AddButton(info, level)
                else
                    info.text = tostring(cat); info.value = tostring(cat); info.func = OnClick
                    UIDropDownMenu_AddButton(info, level)
                end
            end
        elseif level == 2 then
            local category = UIDROPDOWNMENU_MENU_VALUE
            for _, cat in ipairs(items) do
                if type(cat) == "table" and cat.name == category then
                    if cat.spells then
                        for _, spell in ipairs(cat.spells) do
                            info = UIDropDownMenu_CreateInfo()
                            info.text = spell; info.value = spell; info.func = OnClick
                            info.checked = false
                            UIDropDownMenu_AddButton(info, level)
                        end
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
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    MainFrame:SetBackdropColor(1, 1, 1, 1)
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

    local tab4 = CreateFrame("Button", "SHG_MainFrameTab4", MainFrame, "CharacterFrameTabButtonTemplate")
    tab4:SetPoint("LEFT", tab3, "RIGHT", -15, 0); tab4:SetText("Buffs/Debuffs"); tab4:SetID(4); _G[tab4:GetName()] = tab4
    
    local panels = {}
    for i = 1, 4 do
        panels[i] = CreateFrame("Frame", nil, MainFrame)
        panels[i]:SetPoint("TOPLEFT", 15, -45); panels[i]:SetPoint("BOTTOMRIGHT", -15, 45)
        panels[i]:Hide()
    end

    PanelTemplates_SetNumTabs(MainFrame, 4); PanelTemplates_SetTab(MainFrame, 1); panels[1]:Show()

    local function SwitchTab(id)
        PanelTemplates_SetTab(MainFrame, id)
        for i, p in ipairs(panels) do if i == id then p:Show() else p:Hide() end end
    end

    tab1:SetScript("OnClick", function() SwitchTab(1) end)
    tab2:SetScript("OnClick", function() SwitchTab(2) end)
    tab3:SetScript("OnClick", function() SwitchTab(3) end)
    tab4:SetScript("OnClick", function() SwitchTab(4) end)

    -- PANEL 1: General
    local p1 = panels[1]; local y = -10
    local function AddCB1(txt, key)
        local cb = CreateFrame("CheckButton", nil, p1, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 15, y); cb:SetChecked(SHG.DB[key])
        cb:SetScript("OnClick", function(self) 
            SHG.DB[key] = self:GetChecked()
            if key == "locked" and SHG.Frames then SHG.Frames:UpdateAnchor() end
            if SHG.Frames and SHG.Frames.UpdateRoster then SHG.Frames:UpdateRoster() end
            if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end
        end)
        local l = p1:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("LEFT", cb, "RIGHT", 5, 0); l:SetText(txt)
        y = y - 32
    end
    AddCB1("Lock Frames (Hide Anchor)", "locked")
    
    -- Visibility Section
    local vH = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); vH:SetPoint("TOPLEFT", 15, y); vH:SetText("Visibility:"); y = y - 20
    AddCB1("Show in Solo", "showInSolo")
    AddCB1("Show in Party", "showInParty")
    AddCB1("Show in Raid", "showInRaid")
    
    -- Power Section
    y = y - 10
    local pH = p1:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); pH:SetPoint("TOPLEFT", 15, y); pH:SetText("Energy/Power Bars:"); y = y - 20
    AddCB1("Show Mana", "showMana")
    AddCB1("Show Rage", "showRage")
    AddCB1("Show Energy", "showEnergy")
    AddCB1("Show Runic Power", "showRunicPower")

    -- PANEL 2: Display
    local p2 = panels[2]; y = -10
    local col2_x = 240 -- Pozícia druhého stĺpca
    
    local function AddSlider2(txt, key, minf, maxf, step, bx)
        bx = bx or 15
        local s = CreateFrame("Slider", "SHG_Sldr_"..key, p2, "OptionsSliderTemplate")
        s:SetSize(180, 16); s:SetPoint("TOPLEFT", bx, y - 15)
        s:SetMinMaxValues(minf, maxf); s:SetValueStep(step)
        
        local activeVisuals = SHG:GetVisuals()
        local val = activeVisuals[key] or SHG.DB[key] or minf
        s:SetValue(val)
        
        _G[s:GetName() .. "Text"]:SetText(txt .. ": " .. string.format("%.1f", val))
        _G[s:GetName() .. "Low"]:SetText("Low"); _G[s:GetName() .. "High"]:SetText("High")
        s:SetScript("OnValueChanged", function(self, value)
            local v = SHG:GetVisuals()
            v[key] = value
            _G[self:GetName() .. "Text"]:SetText(txt .. ": " .. string.format("%.1f", value))
            if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end
        end)
        y = y - 45
        self.sliders = self.sliders or {}
        self.sliders[key] = s
        return s
    end

    -- Visual Profile Selector
    local lProf = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lProf:SetPoint("TOPLEFT", 15, y); lProf:SetText("Configure Visuals For:")
    
    local profs = {"Party", "Raid"}
    local currentMode = (SHG.Frames and SHG.Frames.testMode == 2) and "Raid" or (GetNumRaidMembers() > 0 and "Raid" or "Party")
    
    local profDD = CreateDropdown(p2, "SHG_DD_VPROF", profs, currentMode, function(v)
        -- Toto je len UI prepínač pre config, reálnu logiku (Party/Raid) riadi hra alebo TestMode
        -- Ale chceme, aby sa slidery updatli na hodnoty daného profilu
        if SHG.Frames then 
            if v == "Raid" then SHG.Frames.testMode = 2 else SHG.Frames.testMode = 1 end
            SHG.Frames:ToggleTestMode(SHG.Frames.testMode)
            SHG.Config:UpdateDisplayPanel() -- Musíme pridať túto funkciu
        end
    end, 160, y+4, 100)
    y = y - 40

    -- STĹPEC 1
    local y_save = y
    AddSlider2("Grid Scale", "gridScale", 0.5, 2.0, 0.05)
    AddSlider2("Frame Width", "frameWidth", 40, 150, 5)
    AddSlider2("Frame Height", "frameHeight", 20, 100, 5)
    AddSlider2("Units per Column", "unitsPerColumn", 1, 40, 1)
    AddSlider2("Max Columns", "maxColumns", 1, 8, 1)
    AddSlider2("Column Spacing", "columnSpacing", 0, 20, 1)
    AddSlider2("Row Offset (Y)", "yOffset", -30, 0, 1)
    AddSlider2("Name Font Size", "nameFontSize", 8, 20, 1)
    AddSlider2("HP Fade Threshold (%)", "fullHpThreshold", 50, 100, 1)
    AddSlider2("Fade Alpha (Opacity)", "fadeAlpha", 0, 1, 0.05)
    
    local lLayout = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    lLayout:SetPoint("TOPLEFT", 15, y); lLayout:SetText("Grid Layout:")
    CreateDropdown(p2, "SHG_DD_LAYOUT", {"Column", "Row"}, SHG.DB.layoutMode or "Column", function(v) 
        SHG.DB.layoutMode = v
        if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end 
    end, 90, y+4, 100)
    y = y - 40
    AddSlider2("Unit Gap (X)", "xOffset", 0, 20, 1)
    
    -- STĹPEC 2
    y = y_save
    
    local lColor = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lColor:SetPoint("TOPLEFT", col2_x, y); lColor:SetText("Color Mode:")
    CreateDropdown(p2, "SHG_DD_CM", HealthModes, SHG.DB.frameColorMode, function(v) SHG.DB.frameColorMode = v; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end, col2_x + 75, y+4, 100)
    y = y - 35
    
    local customFullBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    customFullBtn:SetSize(75, 20); customFullBtn:SetPoint("TOPLEFT", col2_x - 5, y); customFullBtn:SetText("Full HP")
    customFullBtn:SetScript("OnClick", function()
        local c = SHG.DB.frameCustomColor or {r=0,g=1,b=0}
        ShowColorPicker(c.r, c.g, c.b, function(r,g,b) SHG.DB.frameCustomColor = {r=r,g=g,b=b}; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
    end)

    local customLowBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    customLowBtn:SetSize(75, 20); customLowBtn:SetPoint("TOPLEFT", col2_x + 75, y); customLowBtn:SetText("Low HP")
    customLowBtn:SetScript("OnClick", function()
        local c = SHG.DB.frameCustomColorLow or {r=1,g=0,b=0}
        ShowColorPicker(c.r, c.g, c.b, function(r,g,b) SHG.DB.frameCustomColorLow = {r=r,g=g,b=b}; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
    end)

    local bgBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    bgBtn:SetSize(75, 20); bgBtn:SetPoint("TOPLEFT", col2_x + 155, y); bgBtn:SetText("Empty")
    bgBtn:SetScript("OnClick", function()
        local c = SHG.DB.missingHpColor or {r=0.1, g=0.1, b=0.1}
        ShowColorPicker(c.r, c.g, c.b, function(r,g,b) SHG.DB.missingHpColor = {r=r,g=g,b=b}; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
    end)
    y = y - 35
    
    local lTxt = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lTxt:SetPoint("TOPLEFT", col2_x, y); lTxt:SetText("HP Text:")
    CreateDropdown(p2, "SHG_DD_TXT", {"None", "Deficit", "Percent", "Current/Max", "Current"}, SHG.DB.hpTextMode, function(v) SHG.DB.hpTextMode = v; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end, col2_x + 75, y+4, 100)
    y = y - 35
    
    local lNameCol = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lNameCol:SetPoint("TOPLEFT", col2_x, y); lNameCol:SetText("Name Color:")
    CreateDropdown(p2, "SHG_DD_NM", NameColorModes, SHG.DB.nameColorMode, function(v) SHG.DB.nameColorMode = v; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end, col2_x + 75, y+4, 100)
    
    local cNameBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    cNameBtn:SetSize(75, 20); cNameBtn:SetPoint("TOPLEFT", col2_x + 190, y); cNameBtn:SetText("Custom")
    cNameBtn:SetScript("OnClick", function()
        local c = SHG.DB.nameCustomColor or {r=1,g=1,b=1}
        ShowColorPicker(c.r, c.g, c.b, function(r,g,b) SHG.DB.nameCustomColor = {r=r,g=g,b=b}; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
    end)
    y = y - 35
    
    local function AddCB2(txt, key)
        local cb = CreateFrame("CheckButton", nil, p2, "UICheckButtonTemplate")
        cb:SetSize(24, 24); cb:SetPoint("TOPLEFT", col2_x, y); cb:SetChecked(SHG.DB[key])
        cb:SetScript("OnClick", function(self) SHG.DB[key] = self:GetChecked(); if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
        local l = p2:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("LEFT", cb, "RIGHT", 5, 0); l:SetText(txt)
        y = y - 25 -- Tighter spacing for CBs
    end
    
    AddCB2("Fade High HP Units", "fullHpFade")
    AddCB2("Fade No Aggro Units", "aggroFade")
    AddCB2("Aggro Border (Red)", "aggroHighlight")
    y = y - 10
    
    local lFont = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lFont:SetPoint("TOPLEFT", col2_x, y); lFont:SetText("Font:")
    CreateDropdown(p2, "SHG_DD_F", Fonts, SHG.DB.fontName, function(v) SHG.DB.fontName = v; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end, col2_x + 75, y+4, 100)
    y = y - 35
    
    local lBorder = p2:CreateFontString(nil, "OVERLAY", "GameFontNormal"); lBorder:SetPoint("TOPLEFT", col2_x, y); lBorder:SetText("Border:")
    CreateDropdown(p2, "SHG_DD_B", BorderStyles, SHG.DB.borderStyle, function(v) SHG.DB.borderStyle = v; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end, col2_x + 75, y+4, 100)
    y = y - 35
    
    local bColorBtn = CreateFrame("Button", nil, p2, "UIPanelButtonTemplate")
    bColorBtn:SetSize(110, 22); bColorBtn:SetPoint("TOPLEFT", col2_x, y); bColorBtn:SetText("Border Color")
    bColorBtn:SetScript("OnClick", function()
        SHG.DB.borderColor = SHG.DB.borderColor or {r=0, g=0.7, b=1}
        local c = SHG.DB.borderColor
        ShowColorPicker(c.r, c.g, c.b, function(r,g,b) SHG.DB.borderColor = {r=r,g=g,b=b}; if SHG.Frames and SHG.Frames.UpdateVisuals then SHG.Frames:UpdateVisuals() end end)
    end)

    function SHG.Config:UpdateDisplayPanel()
        local v = SHG:GetVisuals()
        local keys = {"gridScale", "frameWidth", "frameHeight", "unitsPerColumn", "maxColumns", "columnSpacing", "yOffset", "nameFontSize", "fullHpThreshold", "fadeAlpha"}
        for _, k in pairs(keys) do
            local s = self.sliders and self.sliders[k]
            if s then
                local val = v[k] or SHG.DB[k] or 1
                s:SetValue(val)
                _G[s:GetName() .. "Text"]:SetText(_G[s:GetName() .. "Text"]:GetText():match("^(.-):") .. ": " .. string.format("%.1f", val))
            end
        end
    end

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
        local mods = { "", "shift-", "ctrl-", "alt-", "ctrl-shift-", "alt-shift-", "alt-ctrl-", "alt-ctrl-shift-" }
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
                    elseif v == "Target" then p.bindings[key] = "action:target"
                    elseif v == "Focus" then p.bindings[key] = "action:focus"
                    elseif v == "Assist" then p.bindings[key] = "action:assist"
                    elseif v == "Context Menu" then p.bindings[key] = "action:menu"
                    elseif v == "Toggle Priority" then p.bindings[key] = "action:priority"
                    elseif v:find("Radial Menu") then
                        p.bindings[key] = "radial:" .. v:match("%d+")
                    else
                        p.bindings[key] = "spell:" .. v 
                    end
                end, 120, -4, 220) -- Positioned inside the row
                self.rows[i] = row
            end
            row.label:SetText(modLabels[i])
            local key = mod .. "type" .. selectedMouseButton
            row.currentKey = key
            local rawVal = p.bindings[key] or ""
            local currentVal = "None"
            if rawVal:find("^spell:") then currentVal = rawVal:gsub("^spell:", "")
            elseif rawVal:find("^action:") then
                local a = rawVal:gsub("^action:", "")
                if a == "target" then currentVal = "Target"
                elseif a == "focus" then currentVal = "Focus"
                elseif a == "assist" then currentVal = "Assist"
                elseif a == "menu" then currentVal = "Context Menu"
                elseif a == "priority" then currentVal = "Toggle Priority" end
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
        pop:SetToplevel(true)
        pop:SetBackdrop({
            bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
            edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
            tile = true, tileSize = 32, edgeSize = 32,
            insets = { left = 11, right = 12, top = 12, bottom = 11 }
        })
        pop:SetBackdropColor(1, 1, 1, 1)
        self.RadialPop = pop
        
        local currentRadialIdx = 1

        local scroll = CreateFrame("ScrollFrame", "SHG_RadialScrollFrame", pop, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 15, -65); scroll:SetPoint("BOTTOMRIGHT", -35, 45)
        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(300, 400); scroll:SetScrollChild(content)
        
        local title = pop:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -15); title:SetText("Configure Radial")
        
        CreateFrame("Button", nil, pop, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -8, -8)
        
        local spells = GetPlayerSpells()
        local rows = {}

        local function UpdateSlotsUI()
            local menuData = SHG.DB.radialMenus[currentRadialIdx]
            for i = 1, 8 do
                UIDropDownMenu_SetText(rows[i].dd, menuData[i].spell or "None")
                -- We only need to update the callback
                rows[i].dd.callback = function(v) menuData[i].spell = v end
            end
        end

        local menuSelector = CreateDropdown(pop, "SHG_RadialMenuSelector", {"Menu 1", "Menu 2", "Menu 3"}, "Menu 1", function(v)
            currentRadialIdx = tonumber(v:match("%d+"))
            UpdateSlotsUI()
        end, 100, -35, 120)

        for i = 1, 8 do
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(300, 45); row:SetPoint("TOPLEFT", 0, -(i-1)*45)
            
            local sl = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            sl:SetPoint("LEFT", 10, 0); sl:SetText("Slot " .. i .. ":")
            
            local data = SHG.DB.radialMenus[currentRadialIdx][i]
            row.dd = CreateDropdown(row, "SHG_RadialSlotDD_"..i, spells, data.spell or "None", function(v)
                SHG.DB.radialMenus[currentRadialIdx][i].spell = v
            end, 60, 5, 180)
            rows[i] = row
        end
        
        pop:Show()
    end

    SHG.Config:UpdateSpellPanel()

    -- PANEL 4: Auras & Priority
    local p4 = panels[4]; y = -10
    
    -- PRIORITY UNITS SECTION
    local pHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    pHeader:SetPoint("TOPLEFT", 10, y); pHeader:SetText("Priority Units (Shift + Right Click on Frame):")
    y = y - 25
    
    local pListTxt = p4:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    pListTxt:SetPoint("TOPLEFT", 20, y); pListTxt:SetWidth(440); pListTxt:SetJustifyH("LEFT")
    
    function SHG.Config:UpdatePList()
        local t = ""
        for i, name in ipairs(SHG.DB.priorityUnits or {}) do
            t = t .. name .. (i < #SHG.DB.priorityUnits and ", " or "")
        end
        pListTxt:SetText("Current Highlighted: |cffffffff" .. (t ~= "" and t or "None") .. "|r")
    end
    
    local clrBtn = CreateFrame("Button", nil, p4, "UIPanelButtonTemplate")
    clrBtn:SetSize(80, 20); clrBtn:SetPoint("TOPLEFT", 20, y - 40); clrBtn:SetText("Clear All")
    clrBtn:SetScript("OnClick", function() SHG.DB.priorityUnits = {}; SHG.Config:UpdatePList(); if SHG.Frames and SHG.Frames.Header then SHG.Frames:UpdateVisuals() end end)
    
    SHG.Config:UpdatePList()
    y = y - 80

    local bHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    bHeader:SetPoint("TOPLEFT", 10, y); bHeader:SetText("Tracked Spells (Corners & Center):")
    y = y - 30

    local function AddAuraItem(parent, txt, list, key, x, yPos)
        local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", x / 0.8, yPos / 0.8); cb:SetChecked(list[key] ~= nil)
        cb:SetScale(0.8)
        cb:SetScript("OnClick", function(self)
            -- Simple toggle logic for the POC
            -- In a real implementation we would have an Add/Remove system
        end)
        local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("LEFT", cb, "RIGHT", 5, 0); l:SetText(txt)
        return 30
    end

    local _, pCl = UnitClass("player")
    local classBuffs = SHG.DB.trackedBuffs[pCl] or {}
    for i, spellID in ipairs(classBuffs) do
        local name = GetSpellInfo(spellID)
        if name then
            y = y - AddAuraItem(p4, name, classBuffs, i, 20, y)
        end
    end

    y = y - 10
    local dHeader = p4:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dHeader:SetPoint("TOPLEFT", 10, y); dHeader:SetText("Tracked Raid Debuffs (Bottom):")
    y = y - 30

    for i, name in ipairs(SHG.DB.trackedDebuffs) do
        y = y - AddAuraItem(p4, name, SHG.DB.trackedDebuffs, i, 20, y)
    end

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
