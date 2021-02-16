--[[
	Cloudy TradeSkill
	Copyright (c) 2020, Cloudyfa
	All rights reserved.
]]


--- Initialization ---
local numTabs = 0
local searchTxt = ''
local filterMats, filterSkill
local skinUI, loadedUI, delay
local function InitDB()
	-- Create new DB if needed --
	if (not CTradeSkillDB) then
		CTradeSkillDB = {}
		CTradeSkillDB['Size'] = 30
		CTradeSkillDB['Unlock'] = false
		CTradeSkillDB['Fade'] = false
		CTradeSkillDB['Level'] = true
		CTradeSkillDB['Tooltip'] = false
		CTradeSkillDB['Drag'] = false
	end
	if not CTradeSkillDB['Tabs'] then CTradeSkillDB['Tabs'] = {} end
	if not CTradeSkillDB['Bookmarks'] then CTradeSkillDB['Bookmarks'] = {} end

	-- Load UI addons --
	if IsAddOnLoaded('Aurora') then
		skinUI = 'Aurora'
		loadedUI = unpack(Aurora)
	elseif IsAddOnLoaded('ElvUI') then
		skinUI = 'ElvUI'
		loadedUI = unpack(ElvUI):GetModule('Skins')
	end
end


--- Create Frame ---
local f = CreateFrame('Frame', 'CloudyTradeSkill')
f:RegisterEvent('PLAYER_LOGIN')
f:RegisterEvent('PLAYER_REGEN_ENABLED')
f:RegisterEvent('TRADE_SKILL_LIST_UPDATE')
f:RegisterEvent('TRADE_SKILL_DATA_SOURCE_CHANGED')


--- Local Functions ---
	--- Check Fading State ---
	local function fadeState()
		if CTradeSkillDB['Fade'] then
			f:RegisterEvent('PLAYER_STARTED_MOVING')
			f:RegisterEvent('PLAYER_STOPPED_MOVING')
		else
			f:UnregisterEvent('PLAYER_STARTED_MOVING')
			f:UnregisterEvent('PLAYER_STOPPED_MOVING')
		end
	end

	--- Save Filters ---
	local function saveFilters()
		filterMats = C_TradeSkillUI.GetOnlyShowMakeableRecipes()
		filterSkill = C_TradeSkillUI.GetOnlyShowSkillUpRecipes()
	end

	--- Restore Filters ---
	local function restoreFilters()
		C_TradeSkillUI.SetOnlyShowMakeableRecipes(filterMats)
		C_TradeSkillUI.SetOnlyShowSkillUpRecipes(filterSkill)
	end

	--- Get Player Professions ---
	local function CTS_GetProfessions()
		local mProfs, sProfs = {}, {}
		local prof1, prof2, arch, fishing, cooking, firstaid = GetProfessions()
		local profs = {prof1, prof2, cooking, firstaid}
		for _, prof in pairs(profs) do
			local num, offset, _, _, _, spec = select(5, GetProfessionInfo(prof))
			if (spec and spec ~= 0) then num = 1 end
			for i = 1, num do
				local index = offset + i
				if not IsPassiveSpell(index, BOOKTYPE_PROFESSION) then
					local _, id = GetSpellBookItemInfo(index, BOOKTYPE_PROFESSION)
					if (i == 1) then
						tinsert(mProfs, id)
					else
						tinsert(sProfs, id)
					end
				end
			end
		end
		return mProfs, sProfs
	end

	--- Check Current Tab ---
	local function isCurrentTab(self)
		if self.id and IsCurrentSpell(self.id) then
			if TradeSkillFrame:IsShown() and (self.isSub == 0) then
				CTradeSkillDB['Panel'] = self.id
				restoreFilters()
			end
			self:SetChecked(true)
			self:RegisterForClicks(nil)
		else
			self:SetChecked(false)
			self:RegisterForClicks('AnyDown')
		end
	end

	--- Add Tab Button ---
	local function addTab(id, index, isSub)
		local name, icon, tabType, tabItem
		if (id == 134020) then
			name, icon = select(2, C_ToyBox.GetToyInfo(id))
			tabType = 'toy'
			tabItem = true
		else
			name, _, icon = GetSpellInfo(id)
			if (id == 126462) then
				tabType = 'item'
				tabItem = true
			else
				tabType = 'spell'
			end
		end
		if (not name) or (not icon) then return end

		local tab = _G['CTradeSkillTab' .. index] or CreateFrame('CheckButton', 'CTradeSkillTab' .. index, TradeSkillFrame, 'SpellBookSkillLineTabTemplate, SecureActionButtonTemplate')
		tab:SetScript('OnEvent', isCurrentTab)
		tab:RegisterEvent('CURRENT_SPELL_CAST_CHANGED')

		tab.id = id
		tab.isSub = isSub
		tab.tooltip = name
		tab:SetNormalTexture(icon)
		tab:SetAttribute('type', tabType)
		tab:SetAttribute(tabType, tabItem and name or id)
		isCurrentTab(tab)

		if skinUI and not tab.skinned then
			local checkedTexture
			if (skinUI == 'Aurora') then
				checkedTexture = 'Interface\\AddOns\\Aurora\\media\\CheckButtonHilight'
			elseif (skinUI == 'ElvUI') then
				checkedTexture = tab:CreateTexture(nil, 'HIGHLIGHT')
				checkedTexture:SetColorTexture(1, 1, 1, 0.3)
				checkedTexture:SetInside()
				tab:SetHighlightTexture(nil)
			end
			tab:SetCheckedTexture(checkedTexture)
			tab:GetNormalTexture():SetTexCoord(.08, .92, .08, .92)
			tab:GetRegions():Hide()
			tab.skinned = true
		end
	end

	--- Remove Tab Buttons ---
	local function removeTabs()
		for i = 1, numTabs do
			local tab = _G['CTradeSkillTab' .. i]
			if tab and tab:IsShown() then
				tab:UnregisterEvent('CURRENT_SPELL_CAST_CHANGED')
				tab:Hide()
			end
		end
	end

	--- Sort Tabs ---
	local function sortTabs()
		local index = 1
		for i = 1, numTabs do
			local tab = _G['CTradeSkillTab' .. i]
			if tab then
				if CTradeSkillDB['Tabs'][tab.id] then
					tab:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPRIGHT', skinUI and 1 or 0, (-50 * index) + (-50 * tab.isSub))
					--tab:SetPoint('LEFT', TradeSkillFrame, 'TOP', skinUI and 1 or 0, (-50 * index) + (-50 * tab.isSub))
					--tab:SetPoint('TOPLEFT', TradeSkillFrame, 'TOPLEFT', 20 + (45 * index) + (20 * tab.isSub), skinUI and 1 or 0 + 36)
					tab:Show()
					index = index + 1
				else
					tab:Hide()
				end
			end
		end
	end

	--- Update Profession Tabs ---
	local function updateTabs(init)
		local mainTabs, subTabs = CTS_GetProfessions()
		if init and not CTradeSkillDB['Panel'] then
			if mainTabs[1] then
				CTradeSkillDB['Panel'] = mainTabs[1]
			end
		end

		local _, class = UnitClass('player')
		if (class == 'DEATHKNIGHT') and IsUsableSpell(53428) then
			tinsert(mainTabs, 53428) --RuneForging
		elseif (class == 'ROGUE') and IsUsableSpell(1804) then
			tinsert(subTabs, 1804) --PickLock
		end
		if PlayerHasToy(134020) and C_ToyBox.IsToyUsable(134020) then
			tinsert(subTabs, 134020) --ChefHat
		end
		if GetItemCount(87216) ~= 0 then
			tinsert(subTabs, 126462) --ThermalAnvil
		end

		local sameTabs = true
		for i = 1, #mainTabs + #subTabs do
			local id = mainTabs[i] or subTabs[i - #mainTabs]
			if (CTradeSkillDB['Tabs'][id] == nil) then
				CTradeSkillDB['Tabs'][id] = true
				sameTabs = false
			end
		end

		if not sameTabs or (numTabs ~= #mainTabs + #subTabs) then
			removeTabs()
			numTabs = #mainTabs + #subTabs
			for i = 1, numTabs do
				local id = mainTabs[i] or subTabs[i - #mainTabs]
				addTab(id, i, mainTabs[i] and 0 or 1)
			end
			sortTabs()
		end
	end

	--- Update Frame Size ---
	local function updateSize(forced)
		TradeSkillFrame:SetHeight(CTradeSkillDB['Size'] * 16 + 96) --496
		TradeSkillFrame.RecipeInset:SetHeight(CTradeSkillDB['Size'] * 16 + 10) --410
		TradeSkillFrame.DetailsInset:SetHeight(CTradeSkillDB['Size'] * 16 - 10) --390
		TradeSkillFrame.DetailsFrame:SetHeight(CTradeSkillDB['Size'] * 16 - 15) --385
		TradeSkillFrame.DetailsFrame.Background:SetHeight(CTradeSkillDB['Size'] * 16 - 17) --383

		if TradeSkillFrame.RecipeList.FilterBar:IsVisible() then
			TradeSkillFrame.RecipeList:SetHeight(CTradeSkillDB['Size'] * 16 - 11) --389
		else
			TradeSkillFrame.RecipeList:SetHeight(CTradeSkillDB['Size'] * 16 + 5) --405
		end

		if forced then
			if #TradeSkillFrame.RecipeList.buttons < floor(CTradeSkillDB['Size'], 0.5) + 2 then
				local range = TradeSkillFrame.RecipeList.scrollBar:GetValue()
				HybridScrollFrame_CreateButtons(TradeSkillFrame.RecipeList, 'TradeSkillRowButtonTemplate', 0, 0)
				TradeSkillFrame.RecipeList.scrollBar:SetValue(range)
			end
			TradeSkillFrame.RecipeList:Refresh()
		end
	end

	--- Set Bookmark Icon ---
	local function bookmarkIcon(button, texture)
		button:SetNormalTexture(texture)
		button:SetPushedTexture(texture)

		local pushed = button:GetPushedTexture()
		pushed:ClearAllPoints()
		pushed:SetPoint('TOPLEFT', 1, -1)
		pushed:SetPoint('BOTTOMRIGHT', -1, 1)
		pushed:SetVertexColor(0.75, 0.75, 0.75)
	end

	--- Update Bookmarks ---
	local function updateBookmarks()
		local prof = C_TradeSkillUI.GetTradeSkillLine()
		if not prof then return end

		if not CTradeSkillDB['Bookmarks'][prof] then
			CTradeSkillDB['Bookmarks'][prof] = {}
		end

		local saved = CTradeSkillDB['Bookmarks'][prof]
		for i = 1, 8 do
			local button = _G['CTradeSkillBookmark' .. i]
			if saved[i] then
				local info = C_TradeSkillUI.GetRecipeInfo(saved[i])
				bookmarkIcon(button, info and info.icon or 'Interface\\Icons\\INV_Misc_QuestionMark')
				button:Show()
			else
				button:Hide()
			end
		end

		local main = _G['CTradeSkillBookmark0']
		local recipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
		local selected = tContains(saved, recipe)
		if not recipe or (#saved > 7 and not selected) then
			main:Disable()
			main.State:Hide()
		else
			main:Enable()
			main.State:Show()
			if selected then
				main.State:SetTexture('Interface\\PetBattles\\DeadPetIcon')
			else
				main.State:SetTexture('Interface\\PaperDollInfoFrame\\Character-Plus')
			end
		end
	end

	--- Add Bookmark ---
	local function addBookmark(index)
		local button = _G['CTradeSkillBookmark' .. index] or CreateFrame('Button', 'CTradeSkillBookmark' .. index, TradeSkillFrame.FilterButton)
		button:SetHighlightTexture('Interface\\Buttons\\ButtonHilight-Square', 'ADD')
		button:RegisterForClicks('LeftButtonDown', 'RightButtonDown')
		button:SetPoint('LEFT', -40 - (index * 25), 0)
		button:SetSize(24, 24)
		button:SetID(index)

		if (index == 0) then
			bookmarkIcon(button, 'Interface\\Icons\\INV_Misc_Book_09')
			button.State = button:CreateTexture(nil, 'OVERLAY')
			button.State:SetSize(12, 12)
			button.State:SetPoint('BOTTOMRIGHT', -3, 3)
		else
			button:Hide()
		end

		button:SetScript('OnClick', function(self, mouse)
			local prof = C_TradeSkillUI.GetTradeSkillLine()
			local saved = CTradeSkillDB['Bookmarks'][prof]
			local recipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
			if (self:GetID() == 0) then
				if tContains(saved, recipe) then
					for i = #saved, 1, -1 do
						if (saved[i] == recipe) then
							tremove(saved, i)
						end
					end
				else
					if (#saved < 8) then
						tinsert(saved, recipe)
					end
				end
				updateBookmarks()
			else
				if (mouse == 'LeftButton') then
					local info = C_TradeSkillUI.GetRecipeInfo(saved[self:GetID()])
					if info.learned then
						TradeSkillFrame.RecipeList:OnLearnedTabClicked()
					else
						TradeSkillFrame.RecipeList:OnUnlearnedTabClicked()
					end
					TradeSkillFrame.RecipeList:SelectedAndForceRecipeIDIntoView(saved[self:GetID()])
				elseif (mouse == 'RightButton') then
					tremove(saved, self:GetID())
					updateBookmarks()
				end
			end
		end)

		button:SetScript('OnEnter', function(self)
			local prof = C_TradeSkillUI.GetTradeSkillLine()
			local saved = CTradeSkillDB['Bookmarks'][prof]
			GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
			if (self:GetID() > 0) then
				GameTooltip:SetRecipeResultItem(saved[self:GetID()])
			else
				local recipe = TradeSkillFrame.RecipeList:GetSelectedRecipeID()
				local selected = tContains(saved, recipe)
				GameTooltip:AddLine(selected and REMOVE or ADD, 1, 1, 1)
			end
			GameTooltip:Show()
		end)
		button:SetScript('OnLeave', function()
			GameTooltip:Hide()
		end)
	end

	--- Create Bookmarks ---
	local function createBookmarks()
		for i = 0, 8 do
			addBookmark(i)
		end
		hooksecurefunc(TradeSkillFrame.RecipeList, 'RefreshDisplay', updateBookmarks)
	end

	--- Update Frame Position ---
	local function updatePosition()
		if CTradeSkillDB['Unlock'] then
			UIPanelWindows['TradeSkillFrame'].area = nil
			TradeSkillFrame:ClearAllPoints()
			if CTradeSkillDB['OffsetX'] and CTradeSkillDB['OffsetY'] then
				TradeSkillFrame:SetPoint('TOPLEFT', UIParent, 'BOTTOMLEFT', CTradeSkillDB['OffsetX'], CTradeSkillDB['OffsetY'])
			else
				TradeSkillFrame:SetPoint('TOPLEFT', UIParent, 'TOPLEFT', GetUIPanel('left') and 623 or 16, -116)
			end
		else
			UpdateUIPanelPositions(TradeSkillFrame)
		end
	end


--- Create Movable Bar ---
local createMoveBar = function()
	local movBar = CreateFrame('Button', nil, TradeSkillFrame)
	movBar:SetPoint('TOPRIGHT', TradeSkillFrame)
	movBar:SetSize(610, 24)
	movBar:SetScript('OnMouseDown', function(_, button)
		if (button == 'LeftButton') then
			if CTradeSkillDB['Unlock'] then
				TradeSkillFrame:SetMovable(true)
				TradeSkillFrame:StartMoving()
			end
		elseif (button == 'RightButton') then
			if not UnitAffectingCombat('player') then
				CTradeSkillDB['OffsetX'] = nil
				CTradeSkillDB['OffsetY'] = nil
				updatePosition()
			end
		end
	end)
	movBar:SetScript('OnMouseUp', function(_, button)
		if (button == 'LeftButton') then
			TradeSkillFrame:StopMovingOrSizing()
			TradeSkillFrame:SetMovable(false)

			CTradeSkillDB['OffsetX'] = TradeSkillFrame:GetLeft()
			CTradeSkillDB['OffsetY'] = TradeSkillFrame:GetTop()
		end
	end)
end


--- Create Resize Bar ---
local createResizeBar = function()
	local resizeBar = CreateFrame('Button', nil, TradeSkillFrame)
	resizeBar:SetPoint('BOTTOM', TradeSkillFrame)
	resizeBar:SetSize(670, 6)
	resizeBar:SetScript('OnMouseDown', function(_, button)
		if (button == 'LeftButton') and not UnitAffectingCombat('player') then
			TradeSkillFrame:SetResizable(true)
			TradeSkillFrame:SetMinResize(670, 512)
			TradeSkillFrame:SetMaxResize(670, TradeSkillFrame:GetTop())
			TradeSkillFrame:StartSizing('BOTTOM')
		end
	end)
	resizeBar:SetScript('OnMouseUp', function(_, button)
		if (button == 'LeftButton') and not UnitAffectingCombat('player') then
			TradeSkillFrame:StopMovingOrSizing()
			TradeSkillFrame:SetResizable(false)
			updateSize(true)
		end
	end)
	resizeBar:SetScript('OnEnter', function()
		if not UnitAffectingCombat('player') then
			SetCursor('CAST_CURSOR')
		end
	end)
	resizeBar:SetScript('OnLeave', function()
		if not UnitAffectingCombat('player') then
			ResetCursor()
		end
	end)
end


--- Refresh TSFrame ---
TradeSkillFrame:HookScript('OnSizeChanged', function(self)
	if self:IsShown() and not UnitAffectingCombat('player') then
		CTradeSkillDB['Size'] = (self:GetHeight() - 96) / 16
		updateSize()
	end
end)


--- Refresh RecipeList ---
hooksecurefunc(TradeSkillFrame.RecipeList, 'UpdateFilterBar', function(self)
	if self.FilterBar:IsVisible() then
		self:SetHeight(CTradeSkillDB['Size'] * 16 - 11) --389
	else
		self:SetHeight(CTradeSkillDB['Size'] * 16 + 5) --405
	end
end)


--- Refresh RecipeButton ---
TradeSkillFrame.RecipeList:HookScript('OnUpdate', function(self, ...)
	for i = 1, #self.buttons do
		local button = self.buttons[i]

		--- Button Draggable ---
		if not button.CTSDrag then
			button:RegisterForDrag('LeftButton')
			button:SetScript('OnDragStart', function(self)
				if CTradeSkillDB and CTradeSkillDB['Drag'] then
					if not UnitAffectingCombat('player') then
						if self.tradeSkillInfo and self.tradeSkillInfo.learned then
							if not self.isHeader then
								PickupSpell(self.tradeSkillInfo.recipeID)
							end
						end
					end
				end
			end)
			button.CTSDrag = true
		end

		--- Button Tooltip ---
		if not button.CTSTip then
			button:HookScript('OnEnter', function(self)
				if CTradeSkillDB and CTradeSkillDB['Tooltip'] then
					if self.tradeSkillInfo and not self.isHeader then
						local link = C_TradeSkillUI.GetRecipeLink(self.tradeSkillInfo.recipeID)
						if link then
							GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
							GameTooltip:SetHyperlink(link)
						end
					end
				end
			end)
			button:HookScript('OnLeave', function()
				if CTradeSkillDB and CTradeSkillDB['Tooltip'] then
					GameTooltip:Hide()
				end
			end)
			button.CTSTip = true
		end

		--- Required Level ---
		if CTradeSkillDB and CTradeSkillDB['Level'] then
			if not button.CTSLevel then
				button.CTSLevel = button:CreateFontString(nil, 'ARTWORK', 'GameFontNormalSmall')
				button.CTSLevel:SetPoint('RIGHT', button.Text, 'LEFT', 1, 0)
			end

			if button.tradeSkillInfo and not button.isHeader then
				local recipe = button.tradeSkillInfo.recipeID
				local item = C_TradeSkillUI.GetRecipeItemLink(recipe)
				if item then
					local quality, _, level = select(3, GetItemInfo(item))
					if quality and level and level > 1 then
						button.CTSLevel:SetText(level)
						button.CTSLevel:SetTextColor(GetItemQualityColor(quality))
					else
						button.CTSLevel:SetText('')
					end
				end
			else
				button.CTSLevel:SetText('')
			end
		else
			if button.CTSLevel then
				button.CTSLevel:SetText('')
			end
		end
	end
end)


--- Collapse Recipes ---
hooksecurefunc(TradeSkillFrame.RecipeList, 'OnHeaderButtonClicked', function(self, _, info, button)
	if (button ~= 'RightButton') then return end

	local collapsed = self:IsCategoryCollapsed(info.categoryID)
	local subCat = C_TradeSkillUI.GetSubCategories(info.categoryID)
	if subCat then
		collapsed = not self:IsCategoryCollapsed(subCat)
	end

	local allCategories = {C_TradeSkillUI.GetCategories()}
	for _, catId in pairs(allCategories) do
		local subCategories = {C_TradeSkillUI.GetSubCategories(catId)}
		if #subCategories == 0 then
			self.collapsedCategories[catId] = collapsed
		else
			self.collapsedCategories[catId] = false
			for _, subId in pairs(subCategories) do
				self.collapsedCategories[subId] = collapsed
			end
		end
	end
	self:Refresh()
end)


--- Fix SearchBox ---
hooksecurefunc('ChatEdit_InsertLink', function(link)
	if link and TradeSkillFrame:IsShown() then
		local activeWindow = ChatEdit_GetActiveWindow()
		if activeWindow then return end

		if strfind(link, 'item:', 1, true) or strfind(link, 'enchant:', 1, true) then
			local text = strmatch(link, '|h%[(.+)%]|h|r')
			if text then
				text = strmatch(text, ':%s(.+)') or text
				TradeSkillFrame.SearchBox:SetText(text)
			end
		end
	end
end)


--- Fix StackSplit ---
hooksecurefunc('ContainerFrameItemButton_OnModifiedClick', function(self, button)
	if TradeSkillFrame:IsShown() then
		if (button == 'LeftButton') then
			StackSplitFrame:Hide()
		end
	end
end)


--- Druid Unshapeshift ---
local function injectDruidButtons()
	local _, class = UnitClass('player')
	if (class ~= 'DRUID') then return end

	local function injectMacro(button, text)
		local macro = CreateFrame('Button', nil, button:GetParent(), 'MagicButtonTemplate, SecureActionButtonTemplate')
		macro:SetAttribute('type', 'macro')
		macro:SetAttribute('macrotext', SLASH_CANCELFORM1)
		macro:SetPoint(button:GetPoint())
		macro:SetFrameStrata('HIGH')
		macro:SetText(text)

		if (skinUI == 'Aurora') then
			loadedUI.Reskin(macro)
		elseif (skinUI == 'ElvUI') then
			loadedUI:HandleButton(macro, true)
		end

		macro:HookScript('OnClick', button:GetScript('OnClick'))
		button:HookScript('OnDisable', function()
			button:SetAlpha(1)
			macro:SetAlpha(0)
			macro:RegisterForClicks(nil)
		end)
		button:HookScript('OnEnable', function()
			button:SetAlpha(0)
			macro:SetAlpha(1)
			macro:RegisterForClicks('LeftButtonDown')
		end)
	end
	injectMacro(TradeSkillFrame.DetailsFrame.CreateButton, CREATE_PROFESSION)
	injectMacro(TradeSkillFrame.DetailsFrame.CreateAllButton, CREATE_ALL)
end


--- Enchanting Vellum ---
local function injectVellumButton()
	local vellum = CreateFrame('Button', nil, TradeSkillFrame, 'MagicButtonTemplate')
	if (skinUI == 'Aurora') then
		loadedUI.Reskin(vellum)
	elseif (skinUI == 'ElvUI') then
		loadedUI:HandleButton(vellum, true)
	end

	vellum:SetSize(90, 22)
	vellum:SetPoint('RIGHT', TradeSkillFrame.DetailsFrame.CreateButton, 'LEFT')
	vellum:SetScript('OnClick', function()
		C_TradeSkillUI.CraftRecipe(TradeSkillFrame.DetailsFrame.selectedRecipeID)
		UseItemByName(38682)
	end)

	hooksecurefunc(TradeSkillFrame.DetailsFrame, 'RefreshButtons', function(self)
		if (select(6, C_TradeSkillUI.GetTradeSkillLine()) ~= 333) or C_TradeSkillUI.IsTradeSkillLinked() or not self.createVerbOverride then
			vellum:Hide()
		else
			local recipeInfo = self.selectedRecipeID and C_TradeSkillUI.GetRecipeInfo(self.selectedRecipeID)
			if recipeInfo then
				local numScrolls = min(recipeInfo.numAvailable, GetItemCount(38682))
				if numScrolls > 0 then
					vellum:SetText(CREATE_PROFESSION .. ' [' .. numScrolls .. ']')
					vellum:Enable()
				else
					vellum:SetText(CREATE_PROFESSION)
					vellum:Disable()
				end
				vellum:Show()
			else
				vellum:Hide()
			end
		end
	end)
end


--- Warning Dialog ---
StaticPopupDialogs['CTRADESKILL_WARNING'] = {
	text = UNLOCK_FRAME .. ' ' .. REQUIRES_RELOAD:lower() .. '!\n',
	button1 = ACCEPT,
	button2 = CANCEL,
	OnAccept = function()
		CTradeSkillDB['Unlock'] = not CTradeSkillDB['Unlock']
		ReloadUI()
	end,
	OnShow = function()
		_G['CTSOption']:Disable()
	end,
	OnHide = function()
		_G['CTSOption']:Enable()
	end,
	timeout = 0,
	exclusive = 1,
	preferredIndex = 3,
}


--- Dropdown Menu ---
local function CTSDropdown_Init(self, level)
	local info = UIDropDownMenu_CreateInfo()
	if level == 1 then
		info.text = f:GetName()
		info.isTitle = true
		info.notCheckable = true
		UIDropDownMenu_AddButton(info, level)

		info.isTitle = false
		info.disabled = false
		info.isNotRadio = true
		info.notCheckable = false

		info.text = UNLOCK_FRAME
		info.func = function()
			StaticPopup_Show('CTRADESKILL_WARNING')
		end
		info.checked = CTradeSkillDB['Unlock']
		UIDropDownMenu_AddButton(info, level)

		info.text = 'UI ' .. ACTION_SPELL_AURA_REMOVED_BUFF
		info.func = function()
			CTradeSkillDB['Fade'] = not CTradeSkillDB['Fade']
			fadeState()
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Fade']
		UIDropDownMenu_AddButton(info, level)

		info.text = STAT_AVERAGE_ITEM_LEVEL
		info.func = function()
			CTradeSkillDB['Level'] = not CTradeSkillDB['Level']
			TradeSkillFrame.RecipeList:Refresh()
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Level']
		UIDropDownMenu_AddButton(info, level)

		info.text = DISPLAY .. ' ' .. INFO
		info.func = function()
			CTradeSkillDB['Tooltip'] = not CTradeSkillDB['Tooltip']
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Tooltip']
		UIDropDownMenu_AddButton(info, level)

		info.text = DRAG_MODEL .. ' ' .. AUCTION_CATEGORY_RECIPES
		info.func = function()
			CTradeSkillDB['Drag'] = not CTradeSkillDB['Drag']
		end
		info.keepShownOnClick = true
		info.checked = CTradeSkillDB['Drag']
		UIDropDownMenu_AddButton(info, level)

		info.func = nil
		info.checked = 	nil
		info.notCheckable = true
		info.hasArrow = true

		info.text = PRIMARY
		info.value = 1
		info.disabled = UnitAffectingCombat('player')
		UIDropDownMenu_AddButton(info, level)

		info.text = SECONDARY
		info.value = 2
		info.disabled = UnitAffectingCombat('player')
		UIDropDownMenu_AddButton(info, level)
	elseif level == 2 then
		info.isNotRadio = true
		info.keepShownOnClick = true
		if UIDROPDOWNMENU_MENU_VALUE == 1 then
			for i = 1, numTabs do
				local tab = _G['CTradeSkillTab' .. i]
				if tab and (tab.isSub == 0) then
					info.text = tab.tooltip
					info.func = function()
						CTradeSkillDB['Tabs'][tab.id] = not CTradeSkillDB['Tabs'][tab.id]
						sortTabs()
					end
					info.checked = CTradeSkillDB['Tabs'][tab.id]
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif UIDROPDOWNMENU_MENU_VALUE == 2 then
			for i = 1, numTabs do
				local tab = _G['CTradeSkillTab' .. i]
				if tab and (tab.isSub == 1) then
					info.text = tab.tooltip
					info.func = function()
						CTradeSkillDB['Tabs'][tab.id] = not CTradeSkillDB['Tabs'][tab.id]
						sortTabs()
					end
					info.checked = CTradeSkillDB['Tabs'][tab.id]
					UIDropDownMenu_AddButton(info, level)
				end
			end
		end
	end
end


--- Create Option Menu ---
local function createOptions()
	if not _G['CTSDropdown'] then
		local menu = CreateFrame('Frame', 'CTSDropdown', TradeSkillFrame, 'UIDropDownMenuTemplate')
		UIDropDownMenu_Initialize(CTSDropdown, CTSDropdown_Init, 'MENU')
	end

	--- Option Button ---
	local button = CreateFrame('Button', 'CTSOption', TradeSkillFrame, 'UIPanelButtonTemplate')
	button:SetScript('OnClick', function(self) ToggleDropDownMenu(1, nil, CTSDropdown, self, 2, -6) end)
	button:SetPoint('RIGHT', TradeSkillFrameCloseButton, 'LEFT', 3.5, 0.6)
	button:SetFrameStrata('HIGH')
	button:SetText('CTS')
	button:SetSize(38, 23)

	if (skinUI == 'Aurora') then
		loadedUI.Reskin(button)
	elseif (skinUI == 'ElvUI') then
		button:StripTextures(true)
		button:CreateBackdrop('Default', true)
		button.backdrop:SetAllPoints()
	end
end


--- Force ESC Close ---
hooksecurefunc('ToggleGameMenu', function()
	if CTradeSkillDB['Unlock'] and TradeSkillFrame:IsShown() then
		C_TradeSkillUI.CloseTradeSkill()
		HideUIPanel(GameMenuFrame)
	end
end)


--- Handle Events ---
f:SetScript('OnEvent', function(self, event, ...)
	if (event == 'PLAYER_LOGIN') then
		InitDB()
		fadeState()
		updatePosition()
		updateTabs(true)
		updateSize(true)
		createMoveBar()
		createResizeBar()
		createBookmarks()
		createOptions()
		injectDruidButtons()
		injectVellumButton()
	elseif (event == 'TRADE_SKILL_LIST_UPDATE') then
		saveFilters()
		searchTxt = TradeSkillFrame.SearchBox:GetText()
	elseif (event == 'TRADE_SKILL_DATA_SOURCE_CHANGED') then
		if not CTradeSkillDB then return end
		if UnitAffectingCombat('player') then
			delay = true
		else
			updateTabs()
		end
		TradeSkillFrame.SearchBox:SetText(searchTxt)
	elseif (event == 'PLAYER_STARTED_MOVING') then
		TradeSkillFrame:SetAlpha(0.3)
	elseif (event == 'PLAYER_STOPPED_MOVING') then
		TradeSkillFrame:SetAlpha(1.0)
	elseif (event == 'PLAYER_REGEN_ENABLED') then
		if delay then
			updateTabs()
			delay = false
		end
	end
end)
