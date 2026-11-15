-- Flat dark widgets: panels, buttons, chips, segmented controls, search box, dropdowns,
-- sortable tables, card lists and a zone map preview.
local _, ns = ...
local UI = {}
ns.UI = UI
local T = ns.Theme
local WHITE = "Interface\\Buttons\\WHITE8X8"

local function rgb(c, a) return c[1], c[2], c[3], a or c[4] or 1 end

--- Flat backdrop on any frame (frame must inherit BackdropTemplate).
function UI.Skin(f, bg, border)
    if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    f:SetBackdropColor(rgb(bg or T.panel))
    f:SetBackdropBorderColor(rgb(border or T.border))
end

function UI.Panel(parent, bg, border)
    local p = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Skin(p, bg, border)
    return p
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
    fs:SetTextColor(rgb(T.accent))
    return fs
end

function UI.Muted(parent, text, font)
    local fs = UI.Label(parent, text, font or "GameFontHighlightSmall")
    fs:SetTextColor(rgb(T.muted))
    return fs
end

local function attachTip(f, title, text)
    if not title then return end
    f:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(title, 1, 1, 1)
        if text then GameTooltip:AddLine(text, nil, nil, nil, true) end
        GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() GameTooltip:Hide() end)
end
UI.AttachTip = attachTip

--- Flat button. style: nil | "primary" | "ghost"
function UI.Button(parent, text, width, onClick, style, height)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width or 100, height or 22)
    local fs = b:CreateFontString(nil, "OVERLAY", style == "primary" and "GameFontNormal" or "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text)
    local bg, border, hover
    if style == "primary" then
        bg, border, hover = T.accentDark, T.accent, { 0.30, 0.55, 0.27, 1 }
        fs:SetTextColor(1, 1, 1)
    elseif style == "ghost" then
        bg, border, hover = { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, T.panel2
    else
        bg, border, hover = T.panel2, T.border, { 0.17, 0.17, 0.20, 1 }
    end
    UI.Skin(b, bg, border)
    b:SetScript("OnEnter", function(self)
        if not self:IsEnabled() then return end
        self:SetBackdropColor(rgb(hover))
        if style ~= "ghost" then self:SetBackdropBorderColor(rgb(T.accent)) end
    end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropColor(rgb(bg))
        self:SetBackdropBorderColor(rgb(border))
    end)
    b:SetScript("OnDisable", function(self) fs:SetAlpha(0.4) self:SetBackdropBorderColor(rgb(T.border)) end)
    b:SetScript("OnEnable", function(self) fs:SetAlpha(1) self:SetBackdropBorderColor(rgb(border)) end)
    b:SetPushedTextOffset(0, -1)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

--- Small square icon button.
function UI.IconButton(parent, texture, size, onClick, tip)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size or 18, size or 18)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetAllPoints()
    b.icon:SetTexture(texture)
    b.icon:SetVertexColor(rgb(T.muted))
    b:SetScript("OnEnter", function(self) self.icon:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnLeave", function(self) self.icon:SetVertexColor(rgb(T.muted)) end)
    if onClick then b:SetScript("OnClick", onClick) end
    attachTip(b, tip)
    return b
end

--- Pill-shaped toggle (chips). icon optional.
function UI.Chip(parent, text, icon, onClick)
    local c = CreateFrame("Button", nil, parent, "BackdropTemplate")
    c:SetHeight(24)
    local x = 9
    if icon then
        c.icon = c:CreateTexture(nil, "ARTWORK")
        c.icon:SetSize(16, 16)
        c.icon:SetPoint("LEFT", 5, 0)
        c.icon:SetTexture(icon)
        c.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        x = 25
    end
    c.text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    c.text:SetPoint("LEFT", x, 0)
    c.text:SetText(text)
    c:SetWidth(math.ceil(c.text:GetStringWidth()) + x + 9)
    UI.Skin(c, T.panel2, T.border)
    function c:SetActive(on)
        self.active = on
        if on then
            self:SetBackdropColor(rgb(T.accentDark))
            self:SetBackdropBorderColor(rgb(T.accent))
            self.text:SetTextColor(1, 1, 1)
        else
            self:SetBackdropColor(rgb(T.panel2))
            self:SetBackdropBorderColor(rgb(T.border))
            self.text:SetTextColor(rgb(T.text))
        end
    end
    c:SetScript("OnEnter", function(self) if not self.active then self:SetBackdropBorderColor(rgb(T.muted)) end end)
    c:SetScript("OnLeave", function(self) self:SetActive(self.active) end)
    c:SetScript("OnClick", onClick)
    c:SetActive(false)
    return c
end

--- Flow chips left to right inside width, wrapping. Returns total height.
function UI.FlowLayout(parent, items, width, gap, x0, y0)
    gap = gap or 6
    local x, y = x0 or 0, y0 or 0
    for _, it in ipairs(items) do
        local w = it:GetWidth()
        if x + w > width and x > (x0 or 0) then x = x0 or 0 y = y - it:GetHeight() - gap end
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
        x = x + w + gap
    end
    return -(y - (y0 or 0)) + (items[1] and items[1]:GetHeight() or 0)
end

--- Segmented control: items = { {key, label, tip}, ... }
function UI.Segmented(parent, items, get, set)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Skin(f, T.panel2, T.border)
    f:SetHeight(24)
    f.buttons = {}
    local x = 1
    for i, it in ipairs(items) do
        local b = CreateFrame("Button", nil, f, "BackdropTemplate")
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.text:SetPoint("CENTER")
        b.text:SetText(it.label)
        local w = math.ceil(b.text:GetStringWidth()) + 20
        b:SetSize(w, 22)
        b:SetPoint("LEFT", x, 0)
        x = x + w
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.key = it.key
        b:SetScript("OnClick", function() set(it.key) f:Refresh() end)
        attachTip(b, it.tip and it.label, it.tip)
        f.buttons[i] = b
    end
    f:SetWidth(x + 1)
    function f:Refresh()
        local v = get()
        for _, b in ipairs(self.buttons) do
            if b.key == v then
                b.bg:SetColorTexture(rgb(T.accentDark))
                b.text:SetTextColor(1, 1, 1)
            else
                b.bg:SetColorTexture(0, 0, 0, 0)
                b.text:SetTextColor(rgb(T.muted))
            end
        end
    end
    f:SetScript("OnShow", f.Refresh)
    f:Refresh()
    return f
end

--- Search box with placeholder and magnifier. onChange(text) fires as you type.
function UI.SearchBox(parent, width, placeholder, onChange, onEnter)
    local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    f:SetSize(width, 28)
    UI.Skin(f, { 0.03, 0.03, 0.04, 1 }, T.border)
    local icon = f:CreateTexture(nil, "ARTWORK")
    icon:SetSize(14, 14)
    icon:SetPoint("LEFT", 8, 0)
    icon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    icon:SetVertexColor(rgb(T.muted))
    local e = CreateFrame("EditBox", nil, f)
    e:SetPoint("LEFT", 26, 0)
    e:SetPoint("RIGHT", -24, 0)
    e:SetHeight(20)
    e:SetFontObject("GameFontHighlight")
    e:SetAutoFocus(false)
    e:SetMaxLetters(60)
    local ph = e:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    ph:SetPoint("LEFT", 1, 0)
    ph:SetText(placeholder or "")
    local clear = UI.IconButton(f, "Interface\\FriendsFrame\\ClearBroadcastIcon", 14, function() e:SetText("") e:ClearFocus() end)
    clear:SetPoint("RIGHT", -6, 0)
    clear:Hide()
    e:SetScript("OnTextChanged", function(self, user)
        local t = self:GetText() or ""
        ph:SetShown(t == "")
        clear:SetShown(t ~= "")
        if onChange then onChange(t, user) end
    end)
    e:SetScript("OnEditFocusGained", function() f:SetBackdropBorderColor(rgb(T.accent)) end)
    e:SetScript("OnEditFocusLost", function() f:SetBackdropBorderColor(rgb(T.border)) end)
    e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    e:SetScript("OnEnterPressed", function(self) if onEnter then onEnter(self:GetText() or "") end self:ClearFocus() end)
    f.edit = e
    function f:SetText(t) e:SetText(t or "") end
    function f:GetText() return e:GetText() end
    return f
end

function UI.Check(parent, label, get, set, tip)
    local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    c:SetSize(24, 24)
    local text = c.Text or c.text
    if not text then
        text = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        text:SetPoint("LEFT", c, "RIGHT", 2, 0)
    end
    text:SetFontObject("GameFontHighlightSmall")
    text:SetText(label)
    c.label = text
    c:SetScript("OnShow", function(self) self:SetChecked(get() and true or false) end)
    c:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
    attachTip(c, tip and label, tip)
    c:SetChecked(get() and true or false)
    return c
end

function UI.Slider(parent, label, minV, maxV, step, get, set, fmt)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(220, 40)
    f.text = UI.Muted(f, label)
    f.text:SetPoint("TOPLEFT")
    local s = CreateFrame("Slider", nil, f, "BackdropTemplate")
    s:SetOrientation("HORIZONTAL")
    s:SetSize(170, 10)
    s:SetPoint("TOPLEFT", 0, -20)
    UI.Skin(s, { 0.03, 0.03, 0.04, 1 }, T.border)
    s:SetThumbTexture(WHITE)
    local thumb = s:GetThumbTexture()
    thumb:SetSize(8, 14)
    thumb:SetVertexColor(rgb(T.accent))
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

-------------------------------------------------------------------------------
-- dropdown (flat popup list)
-------------------------------------------------------------------------------
local popup
local function getPopup()
    if popup then return popup end
    popup = CreateFrame("Frame", "ForagerDropdownPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("FULLSCREEN_DIALOG")
    UI.Skin(popup, T.bg, T.border)
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
                    b:SetHeight(20)
                    b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
                    b:SetPoint("RIGHT", -4, 0)
                    b.hl = b:CreateTexture(nil, "HIGHLIGHT")
                    b.hl:SetAllPoints()
                    b.hl:SetColorTexture(rgb(T.accentDark, 0.6))
                    b.icon = b:CreateTexture(nil, "ARTWORK")
                    b.icon:SetSize(16, 16)
                    b.icon:SetPoint("LEFT", 4, 0)
                    b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                    b.text:SetJustifyH("LEFT")
                    b.text:SetPoint("RIGHT", -4, 0)
                    self.buttons[i] = b
                end
                local it = items[i + self.scroll]
                b.text:ClearAllPoints()
                if it.icon then
                    b.icon:SetTexture(it.icon)
                    b.icon:Show()
                    b.text:SetPoint("LEFT", 24, 0)
                else
                    b.icon:Hide()
                    b.text:SetPoint("LEFT", 6, 0)
                end
                b.text:SetPoint("RIGHT", -4, 0)
                b.text:SetText(it.text)
                b:SetScript("OnClick", function() self:Hide() self.onSelect(it.value, it) end)
                b:Show()
            elseif b then
                b:Hide()
            end
        end
        self:SetHeight(rows * 20 + 8)
    end
    return popup
end

--- Open the shared popup list under an anchor. items = { {text, value, icon}, ... }
function UI.OpenList(anchor, items, onSelect, width)
    local p = getPopup()
    p.owner = anchor
    p.items = items
    p.scroll = 0
    p.onSelect = onSelect
    p:ClearAllPoints()
    p:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
    p:SetWidth(math.max(width or anchor:GetWidth(), 160))
    p:Layout()
    p:SetShown(#items > 0)
end
function UI.CloseList() if popup then popup:Hide() end end

function UI.Dropdown(parent, width, getItems, getValue, onSelect)
    local b = UI.Button(parent, "", width or 160, nil, nil, 22)
    local fs = b:GetFontString()
    fs:ClearAllPoints()
    fs:SetPoint("LEFT", 8, 0)
    fs:SetPoint("RIGHT", -20, 0)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
    arrow:SetSize(14, 14)
    arrow:SetPoint("RIGHT", -4, 0)
    function b:Refresh()
        local v = getValue()
        local label = "-"
        for _, it in ipairs(getItems()) do if it.value == v then label = it.text end end
        self:SetText(label)
    end
    b:SetScript("OnClick", function(self)
        local p = getPopup()
        if p:IsShown() and p.owner == self then p:Hide() return end
        UI.OpenList(self, getItems(), function(v, it) onSelect(v, it) self:Refresh() end, math.max(self:GetWidth(), 200))
    end)
    b:HookScript("OnShow", function(self) self:Refresh() end)
    b:Refresh()
    return b
end

-------------------------------------------------------------------------------
-- scrollbar helper
-------------------------------------------------------------------------------
local function scrollbar(parent, topOffset, onValue)
    local bar = CreateFrame("Slider", nil, parent, "BackdropTemplate")
    bar:SetOrientation("VERTICAL")
    bar:SetWidth(6)
    bar:SetPoint("TOPRIGHT", -3, -(topOffset or 3))
    bar:SetPoint("BOTTOMRIGHT", -3, 3)
    bar:SetBackdrop({ bgFile = WHITE })
    bar:SetBackdropColor(0, 0, 0, 0.35)
    bar:SetThumbTexture(WHITE)
    local th = bar:GetThumbTexture()
    th:SetSize(6, 30)
    th:SetVertexColor(rgb(T.border))
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetScript("OnValueChanged", function(_, v) onValue(math.floor(v + 0.5)) end)
    return bar
end

-------------------------------------------------------------------------------
-- sortable table
-------------------------------------------------------------------------------
--- columns = { {key, label, width, align, get = fn(row)->text, sort = fn(row)->value, tip}, ... }
function UI.Table(parent, columns, visibleRows, onClick, onEnter, rowH)
    local t = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Skin(t, T.panel, T.border)
    rowH = rowH or 20
    t.rows, t.data, t.offset, t.sortKey, t.sortDesc = {}, {}, 0, nil, true
    local width = 0
    for _, c in ipairs(columns) do width = width + c.width end
    t:SetSize(width + 18, (visibleRows + 1) * rowH + 6)
    local head = t:CreateTexture(nil, "BORDER")
    head:SetPoint("TOPLEFT", 1, -1)
    head:SetPoint("TOPRIGHT", -1, -1)
    head:SetHeight(rowH + 2)
    head:SetColorTexture(rgb(T.panel2))
    t.headers = {}
    local x = 5
    for _, c in ipairs(columns) do
        local h = CreateFrame("Button", nil, t)
        h:SetSize(c.width, rowH)
        h:SetPoint("TOPLEFT", x, -2)
        h.text = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        h.text:SetPoint("LEFT", 2, 0)
        h.text:SetPoint("RIGHT", -2, 0)
        h.text:SetJustifyH(c.align or "LEFT")
        h.text:SetText(c.label)
        h.text:SetTextColor(rgb(T.muted))
        h:SetScript("OnClick", function()
            if not c.sort then return end
            if t.sortKey == c.key then t.sortDesc = not t.sortDesc else t.sortKey, t.sortDesc = c.key, true end
            t:Sort()
            t:Refresh()
        end)
        h:SetScript("OnEnter", function(self)
            self.text:SetTextColor(1, 1, 1)
            if c.tip then GameTooltip:SetOwner(self, "ANCHOR_TOP") GameTooltip:AddLine(c.tip, 1, 1, 1, true) GameTooltip:Show() end
        end)
        h:SetScript("OnLeave", function(self) t:HeaderColors() GameTooltip:Hide() end)
        h.col = c
        t.headers[#t.headers + 1] = h
        x = x + c.width
    end
    function t:HeaderColors()
        for _, h in ipairs(self.headers) do
            if h.col.key == self.sortKey then
                h.text:SetTextColor(rgb(T.accent))
                h.text:SetText(h.col.label .. (self.sortDesc and " v" or " ^"))
            else
                h.text:SetTextColor(rgb(T.muted))
                h.text:SetText(h.col.label)
            end
        end
    end
    for i = 1, visibleRows do
        local r = CreateFrame("Button", nil, t)
        r:SetSize(width, rowH)
        r:SetPoint("TOPLEFT", 5, -3 - i * rowH)
        r.bg = r:CreateTexture(nil, "BACKGROUND")
        r.bg:SetAllPoints()
        r.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.025 or 0)
        r.hl = r:CreateTexture(nil, "HIGHLIGHT")
        r.hl:SetAllPoints()
        r.hl:SetColorTexture(1, 1, 1, 0.06)
        r.sel = r:CreateTexture(nil, "BORDER")
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(rgb(T.accentDark, 0.55))
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
    local bar = scrollbar(t, rowH + 4, function(v) t.offset = v t:Refresh() end)
    t.bar = bar
    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(ns.Clamp(t.offset - delta * 3, 0, math.max(0, #t.data - visibleRows)))
    end)
    t.empty = UI.Muted(t, "")
    t.empty:SetPoint("TOP", 0, -rowH * 2 - 6)
    t.empty:SetWidth(width - 40)
    t.empty:SetJustifyH("CENTER")
    function t:Sort()
        self:HeaderColors()
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
    function t:SetData(rows, keepOffset, emptyText)
        self.data = rows or {}
        self:Sort()
        if not keepOffset then self.offset = 0 end
        self.offset = math.min(self.offset, math.max(0, #self.data - visibleRows))
        bar:SetMinMaxValues(0, math.max(0, #self.data - visibleRows))
        bar:SetValue(self.offset)
        bar:SetShown(#self.data > visibleRows)
        self.empty:SetText(#self.data == 0 and (emptyText or "") or "")
        self:Refresh()
    end
    function t:Refresh()
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
    t:HeaderColors()
    return t
end

-------------------------------------------------------------------------------
-- card list (fixed-height rows built by the caller)
-------------------------------------------------------------------------------
--- build(card) creates the card's contents once; fill(card, item, selected) updates it.
function UI.CardList(parent, cardH, visible, build, fill, onClick)
    local l = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    UI.Skin(l, T.panel, T.border)
    l.items, l.offset, l.cards = {}, 0, {}
    for i = 1, visible do
        local c = CreateFrame("Button", nil, l, "BackdropTemplate")
        c:SetHeight(cardH - 4)
        c:SetPoint("TOPLEFT", 4, -4 - (i - 1) * cardH)
        c:SetPoint("RIGHT", -12, 0)
        UI.Skin(c, T.panel2, T.panel2)
        c:SetScript("OnEnter", function(self) if not self.selected then self:SetBackdropBorderColor(rgb(T.muted)) end end)
        c:SetScript("OnLeave", function(self) if not self.selected then self:SetBackdropBorderColor(rgb(T.panel2)) end end)
        c:SetScript("OnClick", function(self)
            if self.item then
                l.selected = self.item
                l:Refresh()
                if onClick then onClick(self.item) end
            end
        end)
        build(c)
        l.cards[i] = c
    end
    l:SetHeight(visible * cardH + 6)
    local bar = scrollbar(l, 3, function(v) l.offset = v l:Refresh() end)
    l:EnableMouseWheel(true)
    l:SetScript("OnMouseWheel", function(_, delta)
        bar:SetValue(ns.Clamp(l.offset - delta, 0, math.max(0, #l.items - visible)))
    end)
    l.empty = UI.Muted(l, "")
    l.empty:SetPoint("TOPLEFT", 14, -14)
    l.empty:SetPoint("RIGHT", -14, 0)
    l.empty:SetJustifyV("TOP")
    function l:SetItems(items, emptyText)
        self.items = items or {}
        self.offset = 0
        bar:SetMinMaxValues(0, math.max(0, #self.items - visible))
        bar:SetValue(0)
        bar:SetShown(#self.items > visible)
        self.empty:SetText(#self.items == 0 and (emptyText or "") or "")
        self:Refresh()
    end
    function l:Refresh()
        for i, c in ipairs(self.cards) do
            local it = self.items[i + self.offset]
            c.item = it
            if it then
                c.selected = it == self.selected
                c:SetBackdropBorderColor(rgb(c.selected and T.accent or T.panel2))
                fill(c, it, c.selected, i + self.offset)
                c:Show()
            else
                c:Hide()
            end
        end
    end
    return l
end

-------------------------------------------------------------------------------
-- zone map preview with area / route / points drawn on top
-------------------------------------------------------------------------------
function UI.MapPreview(parent, w, h)
    local f = CreateFrame("Button", nil, parent, "BackdropTemplate")
    f:SetSize(w, h)
    UI.Skin(f, { 0.02, 0.02, 0.03, 1 }, T.border)
    local clip = CreateFrame("Frame", nil, f)
    clip:SetPoint("TOPLEFT", 1, -1)
    clip:SetPoint("BOTTOMRIGHT", -1, 1)
    clip:SetClipsChildren(true)
    local canvas = CreateFrame("Frame", nil, clip)
    canvas:SetAllPoints()
    f.tiles, f.lines, f.dots = {}, {}, {}
    f.noArt = UI.Muted(clip, "Map preview unavailable")
    f.noArt:SetPoint("CENTER")
    f.noArt:Hide()
    local area = canvas:CreateTexture(nil, "ARTWORK", nil, 1)
    local cw, ch = w - 2, h - 2

    local function line(i)
        local l = f.lines[i]
        if not l then l = canvas:CreateLine(nil, "OVERLAY") f.lines[i] = l end
        l:Show()
        return l
    end
    local function dot(i)
        local d = f.dots[i]
        if not d then d = canvas:CreateTexture(nil, "OVERLAY", nil, 2) d:SetTexture("Interface\\Common\\Indicator-Gray") f.dots[i] = d end
        d:Show()
        return d
    end

    local function drawArt(uiMap)
        for _, t in ipairs(f.tiles) do t:Hide() end
        local ok, layers = pcall(C_Map.GetMapArtLayers, uiMap)
        if not ok or type(layers) ~= "table" or not layers[1] then f.noArt:Show() return end
        local L = layers[1]
        local ok2, tex = pcall(C_Map.GetMapArtLayerTextures, uiMap, 1)
        if not ok2 or type(tex) ~= "table" or #tex == 0 then f.noArt:Show() return end
        f.noArt:Hide()
        local cols = math.ceil(L.layerWidth / L.tileWidth)
        local sx, sy = cw / L.layerWidth, ch / L.layerHeight
        for i, fileID in ipairs(tex) do
            local t = f.tiles[i]
            if not t then t = canvas:CreateTexture(nil, "BACKGROUND") f.tiles[i] = t end
            local col, row = (i - 1) % cols, math.floor((i - 1) / cols)
            t:SetTexture(fileID)
            t:SetSize(L.tileWidth * sx, L.tileHeight * sy)
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", canvas, "TOPLEFT", col * L.tileWidth * sx, -row * L.tileHeight * sy)
            t:SetVertexColor(0.75, 0.75, 0.75)
            t:Show()
        end
    end

    --- Show a farm result (or nil to clear).
    function f:SetResult(r)
        for _, l in ipairs(self.lines) do l:Hide() end
        for _, d in ipairs(self.dots) do d:Hide() end
        area:Hide()
        if not r then for _, t in ipairs(self.tiles) do t:Hide() end self.noArt:Hide() return end
        if self.uiMap ~= r.uiMap then drawArt(r.uiMap) self.uiMap = r.uiMap end
        local col = r.cave and T.cave or T.area
        if r.rect then
            area:SetColorTexture(col[1], col[2], col[3], 0.28)
            area:ClearAllPoints()
            area:SetPoint("TOPLEFT", canvas, "TOPLEFT", r.rect[1] * cw, -r.rect[2] * ch)
            area:SetPoint("BOTTOMRIGHT", canvas, "TOPLEFT", r.rect[3] * cw, -r.rect[4] * ch)
            area:Show()
        end
        local nl, nd = 1, 1
        if r.rect then
            local c = { { r.rect[1], r.rect[2] }, { r.rect[3], r.rect[2] }, { r.rect[3], r.rect[4] }, { r.rect[1], r.rect[4] } }
            for i = 1, 4 do
                local p, q = c[i], c[i % 4 + 1]
                local l = line(nl) nl = nl + 1
                l:SetThickness(1.5)
                l:SetColorTexture(col[1], col[2], col[3], 0.9)
                l:SetStartPoint("TOPLEFT", canvas, p[1] * cw, -p[2] * ch)
                l:SetEndPoint("TOPLEFT", canvas, q[1] * cw, -q[2] * ch)
            end
        end
        for i, p in ipairs(r.points or {}) do
            if i > 250 then break end
            local d = dot(nd) nd = nd + 1
            d:SetSize(4, 4)
            d:SetVertexColor(0.95, 0.95, 0.95, 0.75)
            d:SetPoint("CENTER", canvas, "TOPLEFT", p.x * cw, -p.y * ch)
        end
        local pts = r.route and r.route.points or {}
        if #pts > 1 then
            for i = 1, #pts do
                local p, q = pts[i], pts[i % #pts + 1]
                local l = line(nl) nl = nl + 1
                l:SetThickness(2)
                l:SetColorTexture(T.route[1], T.route[2], T.route[3], 0.95)
                l:SetStartPoint("TOPLEFT", canvas, p.x * cw, -p.y * ch)
                l:SetEndPoint("TOPLEFT", canvas, q.x * cw, -q.y * ch)
            end
        end
        -- player
        local px, py, map = ns.Player:Position(r.uiMap)
        if px and map == r.uiMap then
            local d = dot(nd)
            d:SetSize(9, 9)
            d:SetVertexColor(1, 0.85, 0.1, 1)
            d:SetPoint("CENTER", canvas, "TOPLEFT", px * cw, -py * ch)
        end
    end
    return f
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
