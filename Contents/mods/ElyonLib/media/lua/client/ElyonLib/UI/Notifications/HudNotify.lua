--[[
	HudNotify - right HUD toast lane (vanilla Moodle UI + right-dock aware).
	Public surface is neutral names (HudNotify.*), no library-brand prefix.

	HudNotify.push { title?, body?, type|kind?, ttlSeconds|ttlMs?, id?, style = { ... } }
	HudNotify.pop(id)  HudNotify.clear()
	HudNotify.configure(patch)       -- merges into HudNotify.defaults
	HudNotify.snapshotDefaults()     -- shallow copy for mods to inspect/copy
	HudNotify.hooks.beforePush(opts) optional; return false to cancel push
	HudNotify.hooks.afterPush(id, opts)  HudNotify.hooks.beforePop / afterPop(id, info)

	info for pop hooks: { silent = bool, card = ISPanel } (beforePop may return false to cancel)

	style / defaults knobs include: PAD_TOP, GAP_Y, CARD_W_MAX, ENTER_STEP,
	LAYOUT_STEP, EXIT_STEP, SLIDE_IN_OFFSET, SUBTLE_PANEL_ALPHA, TEXT_MUL,
	BORDER_MUL, BODY_MAX_LINES, MOODLE_RIGHT_EXTRA_PADDING,
		GAP_SCREEN_MOODLES, GAP_SCREEN_DOCK, TITLE_FONT, BODY_FONT, ...
		HUD_PLAYER_NUM, MOODLE_LEFT_FROM_PANE_RIGHT, MOODLE_BAND_MAX_W,
		HOST_BOTTOM_PAD - vertical trim of the invisible hit-box; toast stack uses setConsumeMouseEvents(false) (ISToolTip-style).

	Load module: require("ElyonLib/UI/Notifications/HudNotify").
--]]

require("ISUI/ISPanel")
require("ISUI/ISButton")

local Theme = require("ElyonLib/UI/Theme/Theme")
local MathUtils = require("ElyonLib/MathUtils/MathUtils")
local UIUtils = require("ElyonLib/UI/Utils/UIUtils")
local TimerManager = require("ElyonLib/Core/TimerManager")
local TextUtils = require("ElyonLib/TextUtils/TextUtils")

local MenuDock

local clamp = MathUtils.clamp
local frameStep = UIUtils.frameStep

local T = Theme.colors

local HudNotify = {
	defaults = {
		PAD_SCREEN_X = 10,
		PAD_TOP = 64,
		GAP_Y = 6,
		RIGHT_MARGIN = 4,
		GAP_SCREEN_MOODLES = 6,
		MOODLE_RIGHT_EXTRA_PADDING = 0,
		GAP_SCREEN_DOCK = 8,
		SLIDE_IN_OFFSET = 16,
		CARD_W_MAX = 250,
		MIN_CARD_H = 42,
		MAX_CARD_H = 196,
		BODY_MAX_LINES = 8,
		ACCENT_W = 3,
		CLOSE_BTN = 14,
		INSET_TOP = 5,
		TITLE_PAD_X_AFTER_ACCENT = 6,
		BODY_GAP_AFTER_TITLE = 3,
		ENTER_STEP = 0.26,
		LAYOUT_STEP = 0.22,
		EXIT_STEP = 0.26,
		SUBTLE_PANEL_ALPHA = 0.62,
		TEXT_MUL = 0.94,
		BORDER_MUL = 0.46,
		MAX_STACK = 10,
		BOTTOM_MARGIN = 40,
		HOST_BOTTOM_PAD = 10,
		FADE_HOST_STEP = 0.2,
		HUD_PLAYER_NUM = nil,
		MOODLE_LEFT_FROM_PANE_RIGHT = 46,
		MOODLE_BAND_MAX_W = 120,
	},
	apiVersion = 1,
	hooks = {
		beforePush = nil,
		afterPush = nil,
		beforePop = nil,
		afterPop = nil,
	},
}

local function shallowMerge(dest, patch)
	for k, v in pairs(patch or {}) do
		dest[k] = v
	end
	return dest
end

function HudNotify.configure(patch)
	return shallowMerge(HudNotify.defaults, patch)
end

function HudNotify.snapshotDefaults()
	local t = {}
	for k, v in pairs(HudNotify.defaults) do
		t[k] = v
	end
	return t
end

local function overlayStyle(pushStyle)
	local base = HudNotify.defaults
	if type(pushStyle) ~= "table" then
		return base
	end
	local hasKey = false
	for _ in pairs(pushStyle) do
		hasKey = true
		break
	end
	if not hasKey then
		return base
	end
	local o = shallowMerge({}, pushStyle)
	setmetatable(o, { __index = base })
	return o
end

local function getMenuDockModule()
	if not MenuDock then
		MenuDock = require("ElyonLib/UI/MenuDock/MenuDock")
	end
	return MenuDock
end

local function screenSize()
	local core = getCore()
	local w = core:getScreenWidth() or 1920
	local h = core:getScreenHeight() or 1080
	return w, h
end

local function resolveHudPlayerNum(st)
	local n = tonumber(st and st.HUD_PLAYER_NUM)
	if n ~= nil and n >= 0 then
		return math.floor(n)
	end
	local p = getPlayer and getPlayer() or nil
	if p and p.getPlayerNum then
		return p:getPlayerNum()
	end
	return 0
end

local function playerViewport(playerNum)
	playerNum = playerNum or 0
	if getPlayerScreenLeft and getPlayerScreenWidth and getPlayerScreenTop and getPlayerScreenHeight then
		local sx = getPlayerScreenLeft(playerNum) or 0
		local sy = getPlayerScreenTop(playerNum) or 0
		local sw = getPlayerScreenWidth(playerNum)
		local sh = getPlayerScreenHeight(playerNum)
		if type(sw) == "number" and type(sh) == "number" and sw > 1 and sh > 1 then
			return sx, sy, sw, sh
		end
	end
	local w, h = screenSize()
	return 0, 0, w, h
end

local function moodleColumnLeftAbs(mu, paneRight, st)
	local band = tonumber(st.MOODLE_BAND_MAX_W or 120) or 120
	local dist = tonumber(st.MOODLE_LEFT_FROM_PANE_RIGHT or 46) or 46
	local fallback = paneRight - dist

	if not mu or not mu.javaObject then
		return fallback
	end

	local lx = nil
	if mu.getAbsoluteX then
		lx = mu:getAbsoluteX()
	end
	if lx == nil then
		lx = mu:getX()
	end
	if type(lx) ~= "number" or lx ~= lx then
		return fallback
	end

	local minPlausible = paneRight - band
	if lx >= minPlausible - 2 and lx <= paneRight + 8 then
		return lx
	end

	return fallback
end

local function toastColumnRightBound(st, playerNum, paneLeft, paneRight)
	local rb = paneRight - tonumber(st.RIGHT_MARGIN or 4)

	local mu = UIManager.getMoodleUI and UIManager.getMoodleUI(playerNum)
	local ml = moodleColumnLeftAbs(mu, paneRight, st)
	local gx = tonumber(st.GAP_SCREEN_MOODLES or 6)
	local xp = tonumber(st.MOODLE_RIGHT_EXTRA_PADDING or 0)
	rb = math.min(rb, ml - gx - xp)

	local Dock = getMenuDockModule()
	local dg = tonumber(st.GAP_SCREEN_DOCK or 8)
	local dock = Dock and Dock.instance
	if dock and dock.getIsVisible and dock:isVisible() and dock.edge == "right" then
		local dx = dock.getAbsoluteX and dock:getAbsoluteX() or dock:getX()
		if type(dx) == "number" and dx <= paneRight + 2 then
			rb = math.min(rb, dx - dg)
		end
		local rail = dock.rail
		if rail and rail.getIsVisible and rail:isVisible() then
			local rx = rail.getAbsoluteX and rail:getAbsoluteX() or rail:getX()
			if type(rx) == "number" and rx <= paneRight + 2 then
				rb = math.min(rb, rx - dg)
			end
		end
	end

	local pad = tonumber(st.PAD_SCREEN_X or 10)
	return math.max(paneLeft + pad + 1, rb)
end

local function accentKind(kind)
	kind = tostring(kind or "info"):lower()
	if kind == "success" then
		return Theme.copy(T.success)
	end
	if kind == "warning" then
		return Theme.copy(T.warning)
	end
	if kind == "error" then
		return Theme.copy(T.danger)
	end
	if kind == "message" then
		return Theme.copy(T.accent)
	end
	return Theme.copy(T.primary)
end

local function titleFontOf(st)
	return st.TITLE_FONT or UIFont.Small
end

local function bodyFontOf(st)
	return st.BODY_FONT or UIFont.Small
end

-- HudNoticeCard - single toast panel
local HudNoticeCard = ISPanel:derive("HudNoticeCard")

function HudNoticeCard:onClose()
	HudNotify.pop(self.id)
end

function HudNoticeCard:initialise()
	ISPanel.initialise(self)
	local st = self._styLook or HudNotify.defaults
	local bw = tonumber(st.CLOSE_BTN) or 14
	local iy = tonumber(st.INSET_TOP) or 5
	self.closeBtn = ISButton:new(self.width - bw - 4, iy, bw, bw, "", self, HudNoticeCard.onClose)
	self.closeBtn:initialise()
	self.closeBtn:instantiate()
	self.closeBtn:setDisplayBackground(true)
	self.closeBtn.borderColor = Theme.copy(T.borderDim)
	self.closeBtn.backgroundColor = Theme.copy(T.panelDark)
	self.closeBtn.textColor = Theme.copy(T.textMuted)
	self.closeBtn:setTitle("×")
	self:addChild(self.closeBtn)
	if self.closeBtn.javaObject then
		self.closeBtn.javaObject:setConsumeMouseEvents(true)
	end
end

function HudNoticeCard:instantiate()
	ISUIElement.instantiate(self)
	if self.javaObject then
		self.javaObject:setConsumeMouseEvents(false)
	end
end

function HudNoticeCard:onMouseDown(x, y)
	return false
end

function HudNoticeCard:onMouseUp(x, y)
	return false
end

function HudNoticeCard:onMouseUpOutside(x, y)
	return false
end

function HudNoticeCard:onRightMouseDown(x, y)
	return false
end

function HudNoticeCard:onRightMouseUp(x, y)
	return false
end

function HudNoticeCard:onMouseWheel(del)
	return false
end

function HudNoticeCard:applyLayoutChrome()
	local st = self._styLook or HudNotify.defaults
	local bw = tonumber(st.CLOSE_BTN) or 14
	local iy = tonumber(st.INSET_TOP) or 5
	if self.closeBtn then
		self.closeBtn:setX(self.width - bw - 4)
		self.closeBtn:setY(iy)
		self.closeBtn:setWidth(bw)
		self.closeBtn:setHeight(bw)
	end
end

function HudNoticeCard:prerender()
	local st = self._styLook or HudNotify.defaults
	local fade = tonumber(self.fadeMul) or 1
	local paneA = tonumber(st.SUBTLE_PANEL_ALPHA) or 0.62
	local brdM = tonumber(st.BORDER_MUL) or 0.46

	local fill = Theme.copy(T.panelAlt)
	fill.a = (fill.a or 0.82) * paneA * fade

	local bd = Theme.copy(T.border)
	bd.a = (bd.a or 1.0) * brdM * fade

	local fa, fr, fg, fb = Theme.d(fill)
	self:drawRect(0, 0, self.width, self.height, fa, fr, fg, fb)
	local aa, ax, ay, az = Theme.d(bd)
	self:drawRectBorder(0, 0, self.width, self.height, aa * 0.95, ax, ay, az)
end

function HudNoticeCard:render()
	ISPanel.render(self)
	local st = self._styLook or HudNotify.defaults
	local fade = tonumber(self.fadeMul) or 1

	local kind = accentKind(self.kind)
	local kA, kR, kG, kB = Theme.d(kind)
	local accW = tonumber(st.ACCENT_W) or 3
	self:drawRect(0, 0, accW, self.height, kA * 0.74 * fade, kR, kG, kB)

	local titF = titleFontOf(st)
	local bodF = bodyFontOf(st)
	local tx = accW + (tonumber(st.TITLE_PAD_X_AFTER_ACCENT) or 6)
	local ty = tonumber(st.INSET_TOP) or 5
	local bwBtn = tonumber(st.CLOSE_BTN) or 14
	local tw = math.max(32, self.width - tx - bwBtn - 10)

	local tmMul = tonumber(st.TEXT_MUL) or 0.94
	local tr, tg, tb, tta = Theme.t(T.text)
	self:drawText(
		TextUtils.trimToWidth(titF, tostring(self.titleText or ""), tw, "..."),
		tx,
		ty,
		tr * tmMul * fade,
		tg * tmMul * fade,
		tb * tmMul * fade,
		tta * fade,
		titF
	)

	local th =
		getTextManager():MeasureStringY(titF, TextUtils.trimToWidth(titF, tostring(self.titleText or ""), tw, "..."))
	local gap = tonumber(st.BODY_GAP_AFTER_TITLE) or 3
	local by = ty + th + gap
	local lines = TextUtils.wrapLines(self.bodyText or "", bodF, math.max(22, tw), tonumber(st.BODY_MAX_LINES) or 8)
	local tm = getTextManager()
	local lh = (tm.getFontHeight and tm:getFontHeight(bodF)) or 13
	lh = lh + 2
	local mr, mg, mb, ma = Theme.t(T.textMuted)
	for i = 1, #lines do
		self:drawText(lines[i], tx, by, mr * tmMul * fade, mg * tmMul * fade, mb * tmMul * fade, ma * fade, bodF)
		by = by + lh
	end
end

function HudNoticeCard:new(styLook, w, payload)
	local st = HudNotify.defaults
	local oh = tonumber(payload.estimatedHeight) or tonumber(st.MIN_CARD_H)
	local o = ISPanel:new(0, 0, w, oh)
	setmetatable(o, self)
	self.__index = self
	o.background = false
	o._styLook = styLook
	o.id = payload.id
	o.kind = payload.type or "info"
	o.titleText = payload.title or ""
	o.bodyText = payload.body or ""
	o.slideEnterT = 0
	o.slideExitT = 0
	o.pendingDestroy = false
	o.fadeMul = 0
	o.layoutY = tonumber((styLook or HudNotify.defaults).PAD_TOP) or 64
	o.borderColor = Theme.copy(T.border)
	o:setCapture(false)
	return o
end

local GS = {
	host = nil,
	order = {},
	byId = {},
	timerById = {},
}

local HudNoticeHost = ISPanel:derive("HudNoticeHost")

function HudNoticeHost:new()
	local _, sh = screenSize()
	local o = ISPanel:new(0, 0, 200, math.max(24, tonumber(HudNotify.defaults.PAD_TOP or 64)))
	setmetatable(o, self)
	self.__index = self
	o.cards = {}
	o.fadeStack = 0
	o.fadeTarget = 0
	o.background = false
	o.vpSx, o.vpSy, o.vpSw, o.vpSh = 0, 0, 200, sh
	o.hudPlayerNum = 0
	o:setAlwaysOnTop(true)
	o:setCapture(false)
	return o
end

function HudNoticeHost:instantiate()
	ISUIElement.instantiate(self)
	if self.javaObject then
		self.javaObject:setConsumeMouseEvents(false)
	end
end

function HudNoticeHost:onMouseDown(x, y)
	return false
end

function HudNoticeHost:onMouseUp(x, y)
	return false
end

function HudNoticeHost:onMouseUpOutside(x, y)
	return false
end

function HudNoticeHost:onRightMouseDown(x, y)
	return false
end

function HudNoticeHost:onRightMouseUp(x, y)
	return false
end

function HudNoticeHost:onMouseWheel(del)
	return false
end

function HudNoticeHost:initialise()
	ISPanel.initialise(self)
end

local function stampMs()
	if getTimestampMs then
		return getTimestampMs()
	end
	return getTimeInMillis and getTimeInMillis() or (os.time() * 1000)
end

local function hudGeom(h)
	local st = HudNotify.defaults
	local pn = resolveHudPlayerNum(st)
	local sx, sy, sw, sh = playerViewport(pn)
	h.hudPlayerNum = pn
	h.vpSx, h.vpSy, h.vpSw, h.vpSh = sx, sy, sw, sh

	local paneLeft = sx
	local paneRight = sx + sw
	local rb = toastColumnRightBound(st, pn, paneLeft, paneRight)
	local leftPadX = paneLeft + tonumber(st.PAD_SCREEN_X or 10)
	local cw = clamp(rb - leftPadX, 138, tonumber(st.CARD_W_MAX or 250))
	h.slotW = cw
	h:setWidth(cw)
	h:setX(math.max(leftPadX, rb - cw))
	h:setY(sy)
end

local function HudNoticeTrimHost(host, st)
	local vh = tonumber(host.vpSh) or select(2, screenSize())
	st = st or HudNotify.defaults
	local hp = tonumber(st.HOST_BOTTOM_PAD or 10) or 10
	local padTop = tonumber(st.PAD_TOP or 64)
	local n = #host.cards
	local hNew
	if n == 0 then
		hNew = math.min(vh, math.max(8, padTop + hp))
	else
		local bottom = padTop + 28
		for i = 1, n do
			local ch = host.cards[i]
			if ch then
				local y = tonumber(ch:getY())
				local bh = tonumber(ch:getHeight())
				bottom = math.max(bottom, (y or ch.layoutY or padTop) + (bh or 32))
			end
		end
		hNew = math.min(math.max(bottom + hp, hp + 28), vh)
	end
	host:setHeight(hNew)
end

local function ensureHost()
	if GS.host and GS.host.javaObject then
		hudGeom(GS.host)
		return GS.host
	end
	local h = HudNoticeHost:new()
	h:initialise()
	h:instantiate()
	h:addToUIManager()
	h:setVisible(false)
	GS.host = h
	hudGeom(h)
	h:setWantKeyEvents(false)
	return h
end

local function estH(cw, sty, ti, bd, kd)
	local acc = tonumber(sty.ACCENT_W or 3)
	local gx = tonumber(sty.TITLE_PAD_X_AFTER_ACCENT or 6)
	local tw = math.max(26, cw - acc - gx - 24)
	local tft = titleFontOf(sty)
	local bdt = bodyFontOf(sty)
	local tline = TextUtils.trimToWidth(tft, tostring(ti or ""), tw, "...")
	local th = getTextManager():MeasureStringY(tft, tline)
	local lines = TextUtils.wrapLines(bd or "", bdt, math.max(22, tw), tonumber(sty.BODY_MAX_LINES or 8))
	local lh = getTextManager():getFontHeight(bdt) + 2
	accentKind(kd)
	return clamp(
		(tonumber(sty.INSET_TOP or 5)) + th + (tonumber(sty.BODY_GAP_AFTER_TITLE or 3)) + #lines * lh + 6,
		tonumber(sty.MIN_CARD_H or 42),
		tonumber(sty.MAX_CARD_H or 196)
	)
end

local function relayout()
	if not GS.host then
		return
	end
	hudGeom(GS.host)
	local cw = GS.host.slotW
	for i = 1, #GS.host.cards do
		local c = GS.host.cards[i]
		if c and c.javaObject then
			local ht = estH(cw, c._styLook or HudNotify.defaults, c.titleText, c.bodyText, c.kind)
			c:setWidth(cw)
			c:setHeight(ht)
			c:applyLayoutChrome()
		end
	end
end

local function clrT(id)
	id = tostring(id or "")
	if GS.timerById[id] then
		TimerManager:remove(GS.timerById[id])
	end
	GS.timerById[id] = nil
end

local function popInt(id, _silent)
	id = tostring(id or "")
	local e = GS.byId[id]
	if not e then
		return false
	end
	local h = HudNotify.hooks
	if h.beforePop and h.beforePop(id, { silent = _silent == true, card = e.card }) == false then
		return false
	end
	local card = e.card
	clrT(id)
	GS.byId[id] = nil
	for ix = #GS.order, 1, -1 do
		if GS.order[ix] == id then
			table.remove(GS.order, ix)
			break
		end
	end
	card.pendingDestroy = true
	card.slideExitT = math.max(card.slideExitT or 0, 0)
	if HudNotify.hooks.afterPop then
		HudNotify.hooks.afterPop(id, { silent = _silent == true, card = card })
	end
	return true
end

local function trimStack()
	local cap = tonumber(HudNotify.defaults.MAX_STACK or 10)
	while #GS.order > cap do
		popInt(GS.order[1], true)
	end
end

local function enqueue(card)
	local h = ensureHost()
	h:setVisible(true)
	h:bringToTop()
	table.insert(h.cards, 1, card)
	card.slideEnterT = 0
	card.slideExitT = 0
	card.fadeMul = 0
	card.pendingDestroy = false
	relayout()
	card:initialise()
	card:instantiate()
	h:addChild(card)
	h:bringToTop()
	relayout()
	card:applyLayoutChrome()
	return card
end

function HudNoticeHost:update()
	ISPanel.update(self)
	hudGeom(self)
	local st = HudNotify.defaults
	local cw = self.slotW
	local padTop = tonumber(st.PAD_TOP or 64)
	local gapY = tonumber(st.GAP_Y or 6)
	local botMarg = tonumber(st.BOTTOM_MARGIN or 40)
	local slideBase = tonumber(st.SLIDE_IN_OFFSET or 16)
	local entS = tonumber(st.ENTER_STEP or 0.26)
	local layS = tonumber(st.LAYOUT_STEP or 0.22)
	local exS = tonumber(st.EXIT_STEP or 0.26)
	local fadS = tonumber(st.FADE_HOST_STEP or 0.2)
	local enStep = frameStep(entS)
	local mvStep = frameStep(layS)
	local xStep = frameStep(exS)
	local vh = tonumber(self.vpSh) or select(2, screenSize())
	local ymax = vh - botMarg
	local ys = padTop
	for qi = 1, #self.cards do
		local ch = self.cards[qi]
		if ch then
			local hh = ch:getHeight()
			ch.desiredY = clamp(ys, 0, ymax - hh)
			ys = ys + hh + gapY
		end
	end

	for qi = 1, #self.cards do
		local ch = self.cards[qi]
		if ch.pendingDestroy then
			ch.slideExitT = math.min(1, (ch.slideExitT or 0) + xStep)
			ch.fadeMul = math.min(1, ch.slideEnterT or 1) * (1 - (ch.slideExitT or 0))
		else
			ch.slideEnterT = math.min(1, (ch.slideEnterT or 0) + enStep)
			ch.fadeMul = ch.slideEnterT
		end

		local ty = ch.desiredY or padTop
		local ly = ch.layoutY or ty
		ch.layoutY = ly + (ty - ly) * mvStep

		local slideDist = slideBase + ch:getWidth()
		local restX = cw - ch:getWidth()
		local ent = clamp(ch.slideEnterT, 0, 1)
		local xx = restX + (1 - ent) * slideDist
		if ch.pendingDestroy then
			xx = xx + clamp(ch.slideExitT or 0, 0, 1) * slideDist
		end

		local yyclamp = clamp(ch.layoutY, 2, ymax - ch:getHeight() - 2)
		ch:setX(xx)
		ch:setY(yyclamp)
	end

	local ri = 1
	while ri <= #self.cards do
		local ch = self.cards[ri]
		if ch.pendingDestroy and ch.slideExitT >= 0.995 then
			self:removeChild(ch)
			table.remove(self.cards, ri)
		else
			ri = ri + 1
		end
	end

	HudNoticeTrimHost(self, st)

	self.fadeTarget = (#self.cards > 0) and 1 or 0
	self.fadeStack = self.fadeStack + ((self.fadeTarget - self.fadeStack) * frameStep(fadS))
	if math.abs(self.fadeStack - self.fadeTarget) < 0.02 then
		self.fadeStack = self.fadeTarget
	end
	if #self.cards == 0 and self.fadeStack < 0.02 then
		self:setVisible(false)
	end
end

function HudNotify.pop(id)
	if id == nil or id == "" then
		return false
	end
	return popInt(tostring(id), false)
end

function HudNotify.push(opts)
	opts = opts or {}
	if isServer() then
		return nil
	end
	local h = HudNotify.hooks
	if h.beforePush and h.beforePush(opts) == false then
		return nil
	end
	local stLook = overlayStyle(opts.style)
	local tit = TextUtils.trim(tostring(opts.title or ""))
	local bod = TextUtils.trim(tostring(opts.body or ""))
	local id = opts.id
	if id == nil or id == "" then
		id = tostring(stampMs()) .. "_" .. tostring(ZombRand(100000, 999999))
	end
	id = tostring(id)

	local ms
	if tonumber(opts.ttlMs) ~= nil then
		ms = math.max(1, tonumber(opts.ttlMs))
	elseif tonumber(opts.ttlSeconds) and tonumber(opts.ttlSeconds) > 0 then
		ms = math.floor(tonumber(opts.ttlSeconds) * 1000)
	else
		ms = nil
	end

	local hd = ensureHost()
	hudGeom(hd)
	local cw = hd.slotW
	local est = estH(cw, stLook, tit ~= "" and tit or "Notice", bod, opts.type or opts.kind or "info")
	local card = HudNoticeCard:new(stLook, cw, {
		id = id,
		title = tit ~= "" and tit or "Notice",
		body = bod,
		type = opts.type or opts.kind or "info",
		estimatedHeight = est,
	})

	GS.byId[id] = { card = card }
	GS.order[#GS.order + 1] = id

	clrT(id)
	if ms then
		GS.timerById[id] = TimerManager:add(function()
			popInt(id, true)
		end, ms, false)
	end

	enqueue(card)
	trimStack()
	if h.afterPush then
		h.afterPush(id, opts)
	end
	return id
end

function HudNotify.clear()
	while #GS.order > 0 do
		popInt(GS.order[1], true)
	end
end

Events.OnResolutionChange.Add(function()
	if GS.host then
		hudGeom(GS.host)
		relayout()
	end
end)

return HudNotify
