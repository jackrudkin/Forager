-- Small native-looking widgets: buttons, checkboxes, sliders, popup dropdowns and sortable tables.
local _, ns = ...
local UI = {}
ns.UI = UI

function UI.Button(parent, text, width, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 100, 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function UI.Label(parent, text, font)
    local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    fs:SetText(text or "")
    fs:SetJustifyH("LEFT")
    return fs
end

function UI.Header(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    fs:SetJustifyH("LEFT")
    return fs
end

function UI.Check(parent, label, get, set, tip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    local text = c.Text or c.text
    if not text then
        text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    end
    text:SetText(label)
    c.label = text
    c:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    if tip then
        c:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(label, 1, 1, 1)
            GameTooltip:AddLine(tip, nil, nil, nil, true)
            GameTooltip:Show()
        end)
        c:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    c:SetChecked(get() and true or false)
    return c
end

function UI.Slider(parent, label, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 40)
    f.text = UI.Label(f, label, "GameFontNormalSmall")
    f.text:SetPoint("TOPLEFT")
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(200, 16)
    s:SetPoint("TOPLEFT", 0, -16)
    s:SetBackdrop({ bgFile = "Interface\\Buttons\\UI-SliderBar-Background", edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
        tile = true, tileSize = 8, edgeSize = 8, insets = { left = 3, right = 3, top = 6, bottom = 6 } })
    s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(step)
    s:SetObeyStepOnDrag(true)
    f.value = UI.Label(f, "", "GameFontHighlightSmall")
    f.value:SetPoint("LEFT", s, "RIGHT", 8, 0)
    local function show(v) f.value:SetText(fmt and fmt(v) or tostring(v)) end
    s:SetScript("OnValueChanged", function(_, v)
        v = math.floor(v / step + 0.5) * step
        show(v)
        if f.ready then set(v) end
    end)
    f:SetScript("OnShow", function() f.ready = false s:SetValue(get()) show(get()) f.ready = true end)
    s:SetValue(get())
    show(get())
    f.ready = true
    f.slider = s
    return f
end

--- Popup dropdown: button showing current value; click opens a list.
local popup
local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "ForagerDropdownPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    popup:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    popup:EnableMouse(true)
    popup:Hide()
    popup.buttons = {}
    popup:SetScript("OnShow", function(self) self.shownAt = GetTime() end)
    popup:SetScript("OnUpdate", function(self)
        if GetTime() - (self.shownAt or 0) > 0.2 and IsMouseButtonDown("LeftButton") and not self:IsMouseOver() and not (self.owner and self.owner:IsMouseOver()) then
            self:Hide()
        end
    end)
    popup.scroll = 0
    popup:EnableMouseWheel(true)
    popup:SetScript("OnMouseWheel", function(self, delta)
        self.scroll = ns.Clamp(self.scroll - delta * 3, 0, math.max(0, #self.items - 18))
        self:Layout()
    end)
    function popup:Layout()
        local items = self.items
        local rows = math.min(18, #items)
        for i = 1, math.max(rows, #self.buttons) do
            local b = self.buttons[i]
            if i <= rows then
                if not b then
                    b = CreateFrame("Button", nil, self)
                    b:SetHeight(18)
                    b:SetPoint("TOPLEFT", 8, -6 - (i - 1) * 18)
                    b:SetPoint("RIGHT", -8, 0)
                    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    b.text:SetPoint("LEFT", 2, 0)
                    b.text:SetJustifyH("LEFT")
                    b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
                    self.buttons[i] = b
                end
                local it = items[i + self.scroll]
                b.text:SetText(it.text)
                b:SetScript("OnClick", function() self:Hide() self.onSelect(it.value, it) end)
                b:Show()
            elseif b then
                b:Hide()
            end
        end
        self:SetHeight(rows * 18 + 12)
    end
    return popup
end

function UI.Dropdown(parent, width, getItems, getValue, onSelect)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(width or 160, 22)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(16, 16)
    arrow:SetPoint("RIGHT", -2, 0)
    function b:Refresh()
        local v = getValue()
        local label = "-"
        for _, it in ipairs(getItems()) do if it.value == v then label = it.text end end
        self:SetText(label)
    end
    b:SetScript("OnClick", function(self)
        local p = getPopup()
        if p:IsShown() and p.owner == self then p:Hide() return end
        p.owner = self
        p.items = getItems()
        p.scroll = 0
        p.onSelect = function(v, it) onSelect(v, it) self:Refresh() end
        p:ClearAllPoints()
        p:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        p:SetWidth(math.max(self:GetWidth(), 180))
        p:Layout()
        p:Show()
    end)
    b:SetScript("OnShow", function(self) self:Refresh() end)
    b:Refresh()
    return b
end

--- Sortable table. columns = { {key, label, width, align, get = fn(row)->text, sort = fn(row)->value}, ... }
function UI.Table(parent, columns, visibleRows, onClick, onEnter)
    local t = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    t:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    t:SetBackdropColor(0, 0, 0, 0.35)
    local rowH = 18
    t.rows, t.data, t.offset, t.sortKey, t.sortDesc = {}, {}, 0, nil, true
    local width = 0
    for _, c in ipairs(columns) do width = width + c.width end
    t:SetSize(width + 20, (visibleRows + 1) * rowH + 6)
    -- header
    local x = 4
    for _, c in ipairs(columns) do
        local h = CreateFrame("Button", nil, t)
        h:SetSize(c.width, rowH)
        h:SetPoint("TOPLEFT", x, -2)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h.text:SetAllPoints()
        h.text:SetJustifyH(c.align or "LEFT")
        h.text:SetText(c.label)
        h:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        h:SetScript("OnClick", function()
            if not c.sort then return end
            if t.sortKey == c.key then t.sortDesc = not t.sortDesc else t.sortKey, t.sortDesc = c.key, true end
            t:Sort()
            t:Refresh()
        end)
        if c.tip then
            h:SetScript("OnEnter", function(self) GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine(c.tip, 1, 1, 1, true) GameTooltip:Show() end)
            h:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        x = x + c.width
    end
    for i = 1, visibleRows do
        local r = CreateFrame("Button", nil, t)
        r:SetSize(width, rowH)
        r:SetPoint("TOPLEFT", 4, -2 - i * rowH)
        r:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
        r.sel = r:CreateTexture(nil, "BORDER")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(0.3, 0.6, 1, 0.25)
        r.sel:Hide()
        r.cells = {}
        local cx = 0
        for j, c in ipairs(columns) do
            local fs = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", cx + 2, 0)
            fs:SetWidth(c.width - 4)
            fs:SetJustifyH(c.align or "LEFT")
            fs:SetWordWrap(false)
            r.cells[j] = fs
            cx = cx + c.width
        end
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r:SetScript("OnClick", function(self, btn)
            if self.row then
                t.selected = self.row
                t:Refresh()
                if onClick then onClick(self.row, btn) end
            end
        end)
        r:SetScript("OnEnter", function(self) if self.row and onEnter then onEnter(self, self.row) end end)
        r:SetScript("OnLeave", function() GameTooltip:Hide() end)
        t.rows[i] = r
    end
    local bar = CreateFrame("Slider", nil, t, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(12)
    bar:SetPoint("TOPRIGHT", -2, -rowH - 2)
    bar:SetPoint("BOTTOMRIGHT", -2, 2)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    bar:SetBackdropColor(0, 0, 0, 0.4)
    bar:SetThumbTexture("Interface\\Buttons\\UI-ScrollBar-Knob")
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetScript("OnValueChanged", function(_, v) t.offset = math.floor(v + 0.5) t:Refresh(true) end)
    t.bar = bar
    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(ns.Clamp(t.offset - delta * 3, 0, math.max(0, #t.data - visibleRows)))
    end)
    function t:Sort()
        if not self.sortKey then return end
        local col
        for _, c in ipairs(columns) do if c.key == self.sortKey then col = c end end
        if not col or not col.sort then return end
        local desc = self.sortDesc
        table.sort(self.data, function(a, b)
            local va, vb = col.sort(a), col.sort(b)
            if va == vb then return false end
            if type(va) ~= type(vb) then va, vb = tostring(va), tostring(vb) end
            if desc then return va > vb else return va < vb end
        end)
    end
    function t:SetData(rows, keepOffset)
        self.data = rows or {}
        self:Sort()
        if not keepOffset then self.offset = 0 end
        bar:SetMinMaxValues(0, math.max(0, #self.data - visibleRows))
        bar:SetValue(self.offset)
        self:Refresh()
    end
    function t:Refresh(fromBar)
        for i, r in ipairs(self.rows) do
            local row = self.data[i + self.offset]
            r.row = row
            if row then
                for j, c in ipairs(columns) do r.cells[j]:SetText(c.get(row) or "") end
                r.sel:SetShown(self.selected == row)
                r:Show()
            else
                r:Hide()
            end
        end
    end
    return t
end

--- Standard tooltip builder for rows.
function UI.Tip(owner, title, lines)
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:AddLine(title, 1, 1, 1)
    for _, l in ipairs(lines or {}) do
        if type(l) == "table" then GameTooltip:AddDoubleLine(l[1], l[2], 0.8, 0.8, 0.8, 1, 1, 1)
        else GameTooltip:AddLine(l, 0.85, 0.85, 0.85, true) end
    end
    GameTooltip:Show()
end
