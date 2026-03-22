-- [[ SAUSAGEHEALGRID CONFIG ]]
-- Nastavenia addonu podľa Sausage Addon Design System.

local addonName, SHG = ...
SHG.Config = {}
local MainFrame

function SHG.Config:Create()
    if MainFrame then return MainFrame end
    
    MainFrame = CreateFrame("Frame", "SHG_MainFrame", UIParent)
    MainFrame:SetSize(460, 580); MainFrame:SetPoint("CENTER")
    MainFrame:SetMovable(true); MainFrame:EnableMouse(true); MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving); MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    MainFrame:SetFrameStrata("HIGH")
    
    MainFrame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    tinsert(UISpecialFrames, "SHG_MainFrame")

    -- Header
    local h = MainFrame:CreateTexture(nil, "OVERLAY")
    h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); h:SetSize(300, 68); h:SetPoint("TOP", 0, 12)
    local t = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t:SetPoint("TOP", h, "TOP", 0, -14); t:SetText(SHG.Title .. " Config")
    local cBtn = CreateFrame("Button", nil, MainFrame, "UIPanelCloseButton"); cBtn:SetPoint("TOPRIGHT", -8, -8)

    -- Content Background
    local c = CreateFrame("Frame", nil, MainFrame)
    c:SetPoint("TOPLEFT", 20, -50); c:SetPoint("BOTTOMRIGHT", -20, 50)
    c:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    c:SetBackdropColor(0.1, 0.1, 0.1, 0.8); c:SetBackdropBorderColor(0, 0.7, 1, 1)

    local y = -20
    local function AddLabel(txt, color)
        local l = c:CreateFontString(nil, "OVERLAY", "GameFontNormal"); l:SetPoint("TOPLEFT", 15, y)
        if color then l:SetTextColor(color.r, color.g, color.b) end
        l:SetText(txt); y = y - 25
    end

    -- Mouse Bindings Section
    AddLabel("|cFFFFD100Mouse Bindings (Spell Name)|r")
    local binds = {
        {"Left Click", "type1"},
        {"Right Click", "type2"},
        {"Middle Click", "type3"},
        {"Shift + Left", "shift-type1"},
        {"Ctrl + Left", "ctrl-type1"}
    }
    
    for _, b in ipairs(binds) do
        local l = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("TOPLEFT", 25, y); l:SetText(b[1])
        local eb = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
        eb:SetSize(180, 20); eb:SetPoint("TOPLEFT", 140, y + 4); eb:SetAutoFocus(false)
        -- Odstránime "spell:" prefix pre zobrazenie užívateľovi
        local val = SHG.DB.bindings[b[2]] or ""
        eb:SetText(val:gsub("^spell:", ""))
        eb:SetScript("OnTextChanged", function(self) 
            local txt = self:GetText()
            if txt ~= "" then SHG.DB.bindings[b[2]] = "spell:" .. txt else SHG.DB.bindings[b[2]] = nil end
        end)
        y = y - 30
    end

    y = y - 10
    AddLabel("|cFFFFD100General Options|r")
    
    local function AddCB(txt, key)
        local cb = CreateFrame("CheckButton", nil, c, "UICheckButtonTemplate")
        cb:SetPoint("TOPLEFT", 20, y); cb:SetChecked(SHG.DB[key])
        cb:SetScript("OnClick", function(self) SHG.DB[key] = self:GetChecked() end)
        local l = c:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall"); l:SetPoint("LEFT", cb, "RIGHT", 5, 0); l:SetText(txt)
        y = y - 32
    end
    
    AddCB("Show Mana Bars", "showMana")
    AddCB("Show Incoming Heals", "showIncomingHeals")
    AddCB("Show Target Highlight", "showTargetHighlight")

    y = y - 10
    AddLabel("|cFFFFD100Grid Dimensions|r")
    
    local function AddSlider(txt, key, minVal, maxVal, step)
        local slider = CreateFrame("Slider", "SHG_Slider_"..key, c, "OptionsSliderTemplate")
        slider:SetPoint("TOPLEFT", 25, y)
        slider:SetWidth(200)
        slider:SetMinMaxValues(minVal, maxVal)
        slider:SetValueStep(step)
        
        local val = SHG.DB[key] or minVal
        slider:SetValue(val)
        
        _G[slider:GetName().."Low"]:SetText(minVal)
        _G[slider:GetName().."High"]:SetText(maxVal)
        _G[slider:GetName().."Text"]:SetText(txt .. ": " .. val)
        
        slider:SetScript("OnValueChanged", function(self, value)
            SHG.DB[key] = value
            _G[self:GetName().."Text"]:SetText(txt .. ": " .. value)
        end)
        y = y - 45
    end
    
    AddSlider("Frame Width", "frameWidth", 40, 150, 1)
    AddSlider("Frame Height", "frameHeight", 20, 100, 1)

    -- Footer Buttons
    local save = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    save:SetSize(130, 30); save:SetPoint("BOTTOMLEFT", 25, 15); save:SetText("Save & Reload")
    save:SetScript("OnClick", function() ReloadUI() end)

    local update = CreateFrame("Button", nil, MainFrame, "UIPanelButtonTemplate")
    update:SetSize(110, 25); update:SetPoint("BOTTOMRIGHT", -25, 15); update:SetText("Check Updates")
    update:SetScript("OnClick", function() SHG.Config:ShowGitFrame() end)

    -- Branding
    local brand = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    brand:SetPoint("BOTTOM", 0, 15); brand:SetText("by Sausage Party")

    MainFrame:Hide()
    return MainFrame
end

function SHG.Config:ShowGitFrame()
    if not self.GitFrame then
        local G = CreateFrame("Frame", "SHG_GitFrame", UIParent)
        G:SetSize(320, 130); G:SetPoint("CENTER"); G:SetFrameStrata("DIALOG")
        G:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border", tile=true, tileSize=32, edgeSize=32, insets={left=11,right=12,top=12,bottom=11}})
        tinsert(UISpecialFrames, "SHG_GitFrame")
        local h = G:CreateTexture(nil, "OVERLAY"); h:SetTexture("Interface\\DialogFrame\\UI-DialogBox-Header"); h:SetSize(250, 64); h:SetPoint("TOP", 0, 12)
        local t = G:CreateFontString(nil, "OVERLAY", "GameFontNormal"); t:SetPoint("TOP", h, "TOP", 0, -14); t:SetText("UPDATE LINK")
        CreateFrame("Button", nil, G, "UIPanelCloseButton"):SetPoint("TOPRIGHT", -8, -8)
        local d = G:CreateFontString(nil, "OVERLAY", "GameFontNormal"); d:SetPoint("TOP", 0, -35); d:SetText("Press Ctrl+C to copy GitHub link:")
        local eb = CreateFrame("EditBox", nil, G, "InputBoxTemplate"); eb:SetSize(260, 20); eb:SetPoint("TOP", d, "BOTTOM", 0, -15); eb:SetAutoFocus(true)
        local L = "https://github.com/NikowskyWow/SausageHealgrid/releases"
        eb:SetScript("OnTextChanged", function(s) if s:GetText() ~= L then s:SetText(L); s:HighlightText() end end)
        eb:SetScript("OnEscapePressed", function(s) s:ClearFocus(); G:Hide() end)
        G:SetScript("OnShow", function() eb:SetText(L); eb:SetFocus(); eb:HighlightText() end)
        self.GitFrame = G
    end
    self.GitFrame:Show()
end

function SHG.Config:Toggle()
    local f = self:Create()
    if f:IsShown() then f:Hide() else f:Show() end
end
