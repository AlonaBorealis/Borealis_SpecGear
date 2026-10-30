-- SpecGear: при смене спека надевает комплект, выбранный для этого спека в менеджере экипировки.
-- Настройки свои у каждого персонажа: Интерфейс → Модификации → «SpecGear» или /sg.
-- Спек в бою сменить нельзя, поэтому и переодевание всегда идёт вне боя.

local PREFIX = "|cff66bbffSpecGear|r: "
local NONE = "Ничего не делать"
local db

local function say(msg)
	DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. msg)
end

local function setNames()
	local names = {}
	for i = 1, GetNumEquipmentSets() do
		names[#names + 1] = (GetEquipmentSetInfo(i))
	end
	return names
end

local function setExists(name)
	for _, n in ipairs(setNames()) do
		if n == name then return true end
	end
	return false
end

--[[ Переодевание ]]--

-- после смены спека игра ещё долю секунды держит каст и блокирует вещи, поэтому пробуем несколько раз
local pending, tries, wait = nil, 0, 0
local runner = CreateFrame("Frame")
runner:Hide()
runner:SetScript("OnUpdate", function(self, delta)
	wait = wait + delta
	if wait < 0.5 then return end
	wait = 0
	tries = tries + 1
	if InCombatLockdown() or UnitCastingInfo("player") or EquipmentSetContainsLockedItems(pending) then
		if tries < 10 then return end
		say("не получилось надеть «" .. pending .. "»: вещи заняты. Надень вручную.")
	else
		UseEquipmentSet(pending)
		say("надеваю комплект «" .. pending .. "»")
	end
	pending = nil
	self:Hide()
end)

local function equipFor(group)
	local name = db[group]
	if not name then return end
	if not setExists(name) then
		say("комплекта «" .. name .. "» для спека " .. group .. " больше нет. Выбери другой: /sg")
		return
	end
	pending, tries, wait = name, 0, 0
	runner:Show()
end

-- событие смены спека бывает и при входе в игру, поэтому переодеваемся, только когда спек правда другой
local lastGroup
local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("ACTIVE_TALENT_GROUP_CHANGED")
events:SetScript("OnEvent", function(self, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 == "borealis_SpecGear" then
			SpecGearDB = SpecGearDB or {}
			db = SpecGearDB
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		lastGroup = lastGroup or GetActiveTalentGroup()
	else
		local group = GetActiveTalentGroup()
		if lastGroup and group ~= lastGroup then equipFor(group) end
		lastGroup = group
	end
end)

--[[ Настройки ]]--

local panel = CreateFrame("Frame", "SpecGearOptions", InterfaceOptionsFramePanelContainer)
panel.name = "SpecGear"
panel:Hide()

local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("SpecGear — комплект по спеку")

local hint = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
hint:SetWidth(560)
hint:SetJustifyH("LEFT")
hint:SetText("Когда ты меняешь набор талантов, аддон надевает комплект, выбранный здесь для этого спека. "
	.. "Комплекты создаются в окне персонажа, кнопкой менеджера экипировки (её включает галочка "
	.. "«Использовать менеджер экипировки» в настройках интерфейса). Настройки свои у каждого персонажа.")

local current = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
current:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)

local dropdowns = {}
for group = 1, 2 do
	local label = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	label:SetPoint("TOPLEFT", current, "BOTTOMLEFT", 0, -24 - (group - 1) * 40)
	label:SetWidth(90)
	label:SetJustifyH("LEFT")
	label:SetText("Спек " .. group .. ":")

	local dd = CreateFrame("Frame", "SpecGearDropDown" .. group, panel, "UIDropDownMenuTemplate")
	dd:SetPoint("LEFT", label, "RIGHT", -10, -2)
	UIDropDownMenu_SetWidth(dd, 180)
	dd.fill = function()
		local function add(text, value)
			local info = UIDropDownMenu_CreateInfo()
			info.text = text
			info.checked = db[group] == value
			info.func = function()
				db[group] = value
				UIDropDownMenu_SetText(dd, text)
			end
			UIDropDownMenu_AddButton(info)
		end
		add(NONE, nil)
		for _, name in ipairs(setNames()) do add(name, name) end
	end
	dropdowns[group] = dd
end

-- Initialize сразу вызывает заполнение списка, а настройки персонажа появляются только после загрузки аддона,
-- поэтому списки подключаем при первом открытии страницы
local function refresh()
	for _, dd in ipairs(dropdowns) do
		if not dd.ready then
			UIDropDownMenu_Initialize(dd, dd.fill)
			dd.ready = true
		end
	end
	local count = GetNumTalentGroups()
	current:SetText("Сейчас активен спек " .. GetActiveTalentGroup() .. (count < 2 and " (второго спека нет)" or ""))
	for group, dd in ipairs(dropdowns) do
		local name = db[group]
		UIDropDownMenu_SetText(dd, name and (setExists(name) and name or name .. " |cffff5555(нет такого)|r") or NONE)
	end
	if GetNumEquipmentSets() == 0 then
		current:SetText(current:GetText() .. "\n|cffff5555Комплектов пока нет: сохрани их в менеджере экипировки.|r")
	end
end

panel:SetScript("OnShow", refresh)
InterfaceOptions_AddCategory(panel)

SLASH_SPECGEAR1 = "/sg"
SlashCmdList.SPECGEAR = function()
	-- первый вызов в 3.3.5 иногда открывает не ту страницу, второй её исправляет
	InterfaceOptionsFrame_OpenToCategory(panel)
	InterfaceOptionsFrame_OpenToCategory(panel)
end
