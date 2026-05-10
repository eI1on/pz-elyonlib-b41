local ColorUtils = require("ElyonLib/ColorUtils/ColorUtils")

local createColor = ColorUtils.createColor
local copyColor = ColorUtils.copy
local DEFAULT_COLOR = createColor(1, 1, 1, 1)

local Theme = {}

Theme.colors = {
	background = createColor(0.08, 0.08, 0.08, 0.95),
	panel = createColor(0.13, 0.13, 0.13, 0.90),
	panelAlt = createColor(0.15, 0.15, 0.15, 0.82),
	panelDark = createColor(0.06, 0.06, 0.06, 0.96),

	border = createColor(0.40, 0.40, 0.40, 1.00),
	borderLight = createColor(0.55, 0.55, 0.55, 1.00),
	borderDim = createColor(0.22, 0.22, 0.22, 1.00),

	text = createColor(1.00, 1.00, 1.00, 1.00),
	textMuted = createColor(0.78, 0.78, 0.78, 1.00),
	textDim = createColor(0.55, 0.55, 0.55, 1.00),
	info = createColor(0.90, 0.90, 0.90, 1.00),

	primary = createColor(0.28, 0.48, 0.70, 1.00),
	primaryHover = createColor(0.36, 0.56, 0.78, 1.00),
	primaryDark = createColor(0.18, 0.32, 0.52, 1.00),

	success = createColor(0.48, 0.84, 0.42, 1.00),
	successDark = createColor(0.32, 0.58, 0.28, 1.00),
	successPanel = createColor(0.10, 0.16, 0.10, 0.84),

	warning = createColor(0.95, 0.76, 0.33, 1.00),
	warningDark = createColor(0.70, 0.55, 0.22, 1.00),

	danger = createColor(0.88, 0.28, 0.28, 1.00),
	dangerHover = createColor(0.96, 0.36, 0.36, 1.00),
	dangerDark = createColor(0.60, 0.18, 0.18, 1.00),
	dangerPanel = createColor(0.16, 0.10, 0.10, 0.84),

	positive = createColor(0.62, 0.88, 0.60, 1.00),
	negative = createColor(0.92, 0.52, 0.52, 1.00),

	selected = createColor(0.28, 0.48, 0.70, 0.90),
	hovered = createColor(0.24, 0.24, 0.24, 0.90),
	listAlt = createColor(0.15, 0.15, 0.15, 0.75),
	highlight = createColor(0.30, 0.50, 0.72, 1.00),

	focus = createColor(1.00, 1.00, 1.00, 0.90),

	buttonBg = createColor(0.20, 0.20, 0.20, 0.80),
	buttonHover = createColor(0.30, 0.30, 0.30, 0.80),

	disabled = createColor(0.40, 0.40, 0.40, 0.55),

	gold = createColor(0.95, 0.76, 0.33, 1.00),
	accent = createColor(0.52, 0.78, 0.92, 1.00),

	tileClaimed = createColor(0.12, 0.22, 0.27, 0.90),
	tileReady = createColor(0.12, 0.22, 0.14, 0.90),
	tileFuture = createColor(0.12, 0.12, 0.12, 0.90),
	tileLocked = createColor(0.22, 0.16, 0.08, 0.90),

	iconItem = createColor(0.08, 0.08, 0.08, 0.88),
	iconXp = createColor(0.16, 0.24, 0.34, 0.90),
	iconTrait = createColor(0.12, 0.22, 0.14, 0.90),
	iconTraitNeg = createColor(0.24, 0.12, 0.12, 0.90),
	iconCustom = createColor(0.24, 0.20, 0.12, 0.90),

	sectionAccent = createColor(0.90, 0.90, 0.90, 1.00),

	badgeOverlay = createColor(0.00, 0.00, 0.00, 0.72),
	shadow = createColor(0.00, 0.00, 0.00, 0.25),
	scrollTrack = createColor(0.025, 0.025, 0.025, 0.72),
}

function Theme.standardColors()
	local T = Theme.colors

	return {
		BACKGROUND = T.background,
		BG = T.background,
		SECTION = T.panel,
		SECTIONALT = T.panelAlt,
		PANEL = T.panelDark,
		BAND = T.panelDark,
		CARD = T.panelAlt,
		FIELD = T.panel,
		FIELD_DARK = T.panelDark,
		ALT = T.panelAlt,

		BORDER = T.border,
		BORDER_LIGHT = T.borderLight,
		BORDER_DIM = T.borderDim,

		TEXT = T.text,
		TITLE = T.text,
		MUTED = T.textMuted,
		DIM = T.textDim,
		INFO = T.info,
		SECTION_LINE = T.focus,
		FOCUS = T.focus,

		GOOD = T.success,
		READY = T.success,
		POSITIVE = T.positive,
		NEGATIVE = T.negative,
		WARN = T.warning,
		WARNING = T.warning,
		LOCKED = T.warning,
		BAD = T.danger,
		ERROR = T.danger,
		GOLD = T.gold,
		CLAIMED = T.accent,

		SELECT = T.selected,
		SELECTED = T.selected,
		LIST_SELECTED = T.selected,
		LIST_ALT = T.listAlt,
		CARD_HOVER = T.hovered,

		BUTTON = T.buttonBg,
		BUTTON_HOVER = T.buttonHover,
		BUTTON_PRIMARY = T.primary,
		BUTTON_PRIMARY_HOVER = T.primaryHover,
		BUTTON_DANGER = T.danger,
		BUTTON_DANGER_HOVER = T.dangerHover,

		POSITIVE_PANEL = T.successPanel,
		NEGATIVE_PANEL = T.dangerPanel,

		TILE_CLAIMED = T.tileClaimed,
		TILE_READY = T.tileReady,
		TILE_FUTURE = T.tileFuture,
		TILE_LOCKED = T.tileLocked,

		SECTION_ACCENT = T.sectionAccent,
	}
end

function Theme.d(color)
	return color.a or 1, color.r or 0, color.g or 0, color.b or 0
end

function Theme.t(color)
	return color.r or 1, color.g or 1, color.b or 1, color.a or 1
end

function Theme.copy(color)
	return copyColor(color, DEFAULT_COLOR)
end

function Theme.applyButtonStyle(button, variant)
	if not button then
		return
	end

	local T = Theme.colors
	button.borderColor = Theme.copy(T.border)
	button.textColor = Theme.copy(T.text)

	if variant == "primary" then
		button.backgroundColor = Theme.copy(T.primary)
		button.backgroundColorMouseOver = Theme.copy(T.primaryHover)
	elseif variant == "danger" then
		button.backgroundColor = Theme.copy(T.danger)
		button.backgroundColorMouseOver = Theme.copy(T.dangerHover)
	elseif variant == "success" then
		button.backgroundColor = Theme.copy(T.success)
		button.backgroundColorMouseOver = Theme.copy(T.successDark)
	elseif variant == "warning" then
		button.backgroundColor = Theme.copy(T.warning)
		button.backgroundColorMouseOver = Theme.copy(T.warningDark)
	else
		button.backgroundColor = Theme.copy(T.buttonBg)
		button.backgroundColorMouseOver = Theme.copy(T.buttonHover)
	end
end

function Theme.applyFieldStyle(entry)
	if not entry then
		return
	end

	local T = Theme.colors
	entry.backgroundColor = Theme.copy(T.panel)
	entry.borderColor = Theme.copy(T.border)
end

function Theme.applyListStyle(list)
	if not list then
		return
	end

	local T = Theme.colors
	list.backgroundColor = Theme.copy(T.panel)
	list.borderColor = Theme.copy(T.border)
	list.drawBorder = false

	if list.vscroll then
		list.vscroll.backgroundColor = Theme.copy(T.panel)
		list.vscroll.borderColor = Theme.copy(T.border)
	end
end

function Theme.applyComboStyle(combo)
	if not combo then
		return
	end

	local T = Theme.colors
	combo.backgroundColor = Theme.copy(T.panel)
	combo.backgroundColorMouseOver = Theme.copy(T.primary)
	combo.borderColor = Theme.copy(T.border)
	combo.textColor = Theme.copy(T.text)
end

function Theme.applyPanelStyle(panel)
	if not panel then
		return
	end

	local T = Theme.colors
	panel.backgroundColor = Theme.copy(T.background)
	panel.borderColor = Theme.copy(T.border)
end

function Theme.applyTickBoxStyle(tickBox)
	if not tickBox then
		return
	end

	local T = Theme.colors
	tickBox.backgroundColor = Theme.copy(T.background)
	tickBox.borderColor = Theme.copy(T.border)
end

return Theme
