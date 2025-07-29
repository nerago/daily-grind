local gui = LibStub("AceGUI-3.0")
local libDB = LibStub("AceDB-3.0")

local addon = LibStub("AceAddon-3.0"):NewAddon("DailyGrind", "AceEvent-3.0", "AceConsole-3.0")
DAILY_GRIND = addon

local questieDb = QuestieLoader:ImportModule("QuestieDB");
local questieTrackerUtils = QuestieLoader:ImportModule("TrackerUtils");
local questieDistanceUtils = QuestieLoader:ImportModule("DistanceUtils");

function addon:openFrame()	
	local frame = addon.frame
	if not frame then
		frame = self:createMainFrame()
		addon.frame = frame
	end
	
	frame:Show()
end

function addon:toggleFrame()
	if addon.frame and addon.frame:IsVisible() then
		addon.frame:Hide()
	else
		addon:openFrame()
	end
end

function addon:treeTab()
	local data = self:buildData();
	
	local tree = gui:Create("TreeGroup")
	tree:SetStatusTable(self.treeStatus)
	tree:SetTree(data)
	tree:SetTreeWidth(300, true)
	tree:SetLayout("Fill")
	tree:SetCallback("OnGroupSelected", function(...) addon:nodeSelected(...) end)
	
	local label = gui:Create("Label")
	local buttonGo = gui:Create("Button")
	buttonGo:SetText("Map")
	buttonGo:SetWidth(100)
	buttonGo:SetCallback("OnClick", function(...) addon:buttonGoClick(...) end)
	buttonGo:SetDisabled(true)
	
	local questInfo = gui:Create("SimpleGroup")
	questInfo:SetLayout("List")
	questInfo:AddChild(label)
	questInfo:AddChild(buttonGo)
	tree:AddChild(questInfo)
	
	self.tree = tree
	self.label = label
	self.buttonGo = buttonGo
	
	return tree
end

function addon:addTab()
	local group = gui:Create("SimpleGroup")
	group:SetLayout("List")
	group:SetCallback("OnRelease", function() group.frame:SetClipsChildren(false) end)
	group.frame:SetClipsChildren(true)
	
	self:updateGroupList()
	
	local acceptedQueue = self.acceptedQueue
	local minIndex = math.max(#acceptedQueue - 20, 1)
	local maxIndex = #acceptedQueue
	if maxIndex > 0 then
		for i = maxIndex, minIndex, -1 do
			local questId = acceptedQueue[i]
			local questInfo = questieDb.GetQuest(questId)
			if questInfo then
				local category = self:questCategory(questInfo)
				
				local label = gui:Create("Label")
				label:SetText(questInfo.name)
				group:AddChild(label)
				
				local drop = gui:Create("Dropdown")
				drop:SetList(self.groupList, self.groupListOrder)
				drop:SetValue(category)
				drop:SetLabel("Category")
				drop:SetCallback("OnValueChanged", function (_, _, key) addon:onChooseQuestCategory(questId, key) end)
				group:AddChild(drop)
			else
				local label = gui:Create("Label")
				label:SetText("Unknown quest " .. questId)
				group:AddChild(label)
			end
			
			local spacer = gui:Create("Label")
			spacer:SetText(" ")
			group:AddChild(spacer)
		end
	end
	
	return group
end

function addon:filterTab()
	local group = gui:Create("SimpleGroup")
	group:SetLayout("List")
	
	local filterNames = {}
	for key, _ in pairs(addon.categoryFilters) do
		table.insert(filterNames, key)
	end
	table.sort(filterNames)
	
	local filterState = self.db.profile.filter
	for _, key in ipairs(filterNames) do
		local check = gui:Create("CheckBox")
		check:SetValue(filterState[key])
		check:SetLabel(key)
		check:SetCallback("OnValueChanged", function(_, _, value)
			filterState[key] = value
		end)
		group:AddChild(check)
	end
	
	return group
end

function addon:createMainFrame()
	local frame = gui:Create("Frame")
	frame:ReleaseChildren()
	frame:SetTitle("Daily Grind")
	frame:SetLayout("Fill")
	frame:SetWidth(self.db.profile.frameWidth)
	frame:SetHeight(self.db.profile.frameHeight)
	frame:SetCallback("OnClose", function()
		self.db.profile.frameWidth = frame.frame:GetWidth()
		self.db.profile.frameHeight = frame.frame:GetHeight()
		gui:Release(frame)
		self.frame = nil
		self.tree = nil
		self.label = nil
		self.buttonGo = nil
	end)
	
	local tabs = gui:Create("TabGroup")
	tabs:SetLayout("Fill")
	tabs:SetCallback("OnGroupSelected", function (container, _, tabName) 
		container:ReleaseChildren()
		if tabName == "tree" then
			container:AddChild(self:treeTab())
		elseif tabName == "add" then
			container:AddChild(self:addTab())
		else
			container:AddChild(self:filterTab())
		end
	end)
	frame:AddChild(tabs)
	
	tabs:SetTabs({{value = "tree", text = "Progress"}, 
	              {value = "add", text = "Add Recent Quests"}, 
				  {value = "filter", text = "Filter"}})
	tabs:SelectTab("tree")
	
	DAILY_GRIND_MAIN_FRAME = frame.frame
	tinsert(UISpecialFrames, "DAILY_GRIND_MAIN_FRAME")
	
	return frame
end

function addon:getZoneName(zoneId)
	if zoneId then
		if zoneId > 0 then
			return questieTrackerUtils:GetZoneNameByID(zoneId)
		elseif zoneId < 0 then
			return questieTrackerUtils:GetCategoryNameByID(zoneId)
		end
	end
end

local function textUnavailable(text)
	return "|cff808080"..text..FONT_COLOR_CODE_CLOSE
end

local function textAvailable(text)
	return "|cffC0C000"..text..FONT_COLOR_CODE_CLOSE
end

local function textComplete(text)
	return "|cff20E020"..text..FONT_COLOR_CODE_CLOSE
end

function addon:questCategory(questInfo)
	local id = questInfo.Id
	for category, content in pairs(self.db.profile.questTable) do
		if table.contains(content, id) then
			return category
		end
	end
	for category, content in pairs(addon.questTable) do
		if table.contains(content, id) then
			return category
		end
	end
	return self:getZoneName(questInfo.zoneOrSort)
end

function addon:isKnownCategory(id)
	for category, content in pairs(self.db.profile.questTable) do
		if table.contains(content, id) then
			return true
		end
	end
	for category, content in pairs(addon.questTable) do
		if table.contains(content, id) then
			return true
		end
	end
	return false
end

function addon:sortQuests(quests)
	table.sort(quests, function(a,b) 
		if a.status ~= b.status then 
			return a.status < b.status
		else 
			return a.name < b.name 
		end
	end)
end

function addon:headerFor(zoneName, zoneQuests)
	local counts = { 0, 0, 0 }
	for _, quest in ipairs(zoneQuests) do
		counts[quest.status] = counts[quest.status] + 1
	end

	local text = zoneName .. " "
	text = text .. counts[2] .. "/" .. (counts[1] + counts[2])
	return text
end

function addon:buildQuestList()
	local list = {}
	for _, questId in ipairs(addon.quests) do
		list[questId] = 1
	end
	for _, subList in pairs(addon.questTable) do
		for _, questId in ipairs(subList) do
			list[questId] = 1
		end
	end
	for _, subList in pairs(self.db.profile.questTable) do
		for _, questId in ipairs(subList) do
			list[questId] = 1
		end
	end
	return list
end

function addon:buildData()
	local dataByZone = {}
	local zoneNameList = {}
	addon.questLookup = {}
	
	local questList = self:buildQuestList()
	for questId, _ in pairs(questList) do
		local zoneName, item
		local questInfo = questieDb.GetQuest(questId)
		if questInfo then
			zoneName = self:questCategory(questInfo)
			local name = questInfo.name
			local text = name
			local status = 0
			local doable, complete = questieDb.IsDoable(questId), C_QuestLog.IsQuestFlaggedCompleted(questId)
			if complete then
				text = textComplete(text)
				status = 2
			elseif doable then
				text = textAvailable(text)
				status = 1
			else
				text = textUnavailable(text)
				status = 3
			end
			item = { text = text, name = name, value = questId, status = status, quest = questInfo }
			addon.questLookup[questId] = questInfo
		else
			item = { text = "Unknown quest " .. questId, name = "Unknown quest", value = questId, status = 3 }
		end
		
		if not zoneName then zoneName = "Unknown" end
		
		if item then
			local array = dataByZone[zoneName]
			if array == nil then
				array = {}
				dataByZone[zoneName] = array
				table.insert(zoneNameList, zoneName)
			end
			table.insert(array, item)
		end
	end
	
	table.sort(zoneNameList)

	local filterState = self.db.profile.filter
	local permittedZones = {}
	for filter, zonesIncluded in pairs(self.categoryFilters) do
		if filterState[filter] == nil then
			filterState[filter] = true -- set default to true if missing
		end
		if filterState[filter] == true then
			for _, zone in ipairs(zonesIncluded) do
				permittedZones[zone] = true
			end
		else
			for _, zone in ipairs(zonesIncluded) do
				permittedZones[zone] = false
			end
		end
	end
	
	local resultData = {}
	for _, zoneName in ipairs(zoneNameList) do
		if permittedZones[zoneName] ~= false then
			local zoneQuests = dataByZone[zoneName]
			self:sortQuests(zoneQuests)
			
			local headerText = self:headerFor(zoneName, zoneQuests);
			
			local header = { text = headerText, value = zoneName, children = zoneQuests }
			table.insert(resultData, header)
		end
	end
	return resultData
end

function addon:refreshData()
	self:updateGroupList()
	if self.tree then
		self.tree:SetTree(self:buildData())
	end
end

function addon:nodeSelected(_, _, nodePath)
	if nodePath then
		local header, child = string.split("\001", nodePath)
		if child then
			local questId = tonumber(child)
			addon:questSelected(questId)
		end
	end
end

function addon:questSelected(questId)
	local questInfo = addon.questLookup[questId]
	if questInfo then
	    local spawn, zoneId = questieDistanceUtils.GetNearestFinisherOrStarter(questInfo.Finisher)
	    self.currentQuest = questInfo
	    
	    local text = "Quest Id: " .. questId .. "\n"
	    text = text .. "Name: " .. questInfo.name .. "\n"
	    if zoneId then
	    	text = text .. "Zone: " .. self:getZoneName(zoneId) .. "\n"
	    end
		
		-- todo IsDoableVerbose
	    
	    self.label:SetText(text)
		self.buttonGo:SetDisabled(zoneId == nil)
	else
		self.label:SetText("")
		self.buttonGo:SetDisabled(true)
	end
end

function addon:buttonGoClick()
	if self.currentQuest then
		questieTrackerUtils:ShowFinisherOnMap(self.currentQuest)
	end
end

function addon:updateActiveQuests()
	self:refreshData()
end

function addon:acceptQuest(eventName, questLogIndex, questId)
	local acceptedQueue = self.acceptedQueue
	table.insert(acceptedQueue, questId) -- todo limits
	if not self:isKnownCategory(questId) then
		print("DailyGrind: " .. questId .. " not in a category")
	end
end

function addon:OnInitialize()
	self:RegisterChatCommand("daily", "slashCommand")
	self:RegisterEvent("QUEST_ACCEPTED", "acceptQuest")
	self:RegisterEvent("QUEST_REMOVED", "updateActiveQuests")
	self:RegisterEvent("QUEST_TURNED_IN", "updateActiveQuests")
	
	local defaults = { profile = { 
		minimap = {}, 
		questTable = {},
		filter = {},
		frameWidth = 700,
		frameHeight = 700
	} }
	self.db = libDB:New("DailyGrindDB", defaults, true)
	
	local libBroker, libIcon = LibStub("LibDataBroker-1.1"), LibStub("LibDBIcon-1.0")
	local dataObject = libBroker:NewDataObject("DailyGrind", {
		type = "data source",
		text = "Daily Grind",
		icon = 409603,
		OnClick = function(self, btn)
			addon:toggleFrame()
		end,
		OnTooltipShow = function(tooltip)
			if not tooltip or not tooltip.AddLine then return end
			tooltip:AddLine("Daily Grind")
		end,
	})
	libIcon:Register("DailyGrind", dataObject, self.db.profile.minimap)
	
	self.acceptedQueue = {}
	self.treeStatus = {}
	self.groupList = {}
end

function addon:slashCommand(text)
	if text == nil or text == "" then
		self:openFrame()
	elseif string.startswith(text, "set") then
		local count, label = string.match(text, "set (%d+) (%a+)")
		if count and label then
			self:setQuests(count, label)
		else
			print("syntax /daily set # word")
		end
	end
end

-- obsolete soon
function addon:setQuests(count, label)
	local questTable = self.db.profile.questTable
	local acceptedQueue = self.acceptedQueue
	
	local list = questTable[label]
	if not list then
		list = {}
		questTable[label] = list
	end
	
	local minIndex = #acceptedQueue - count + 1
	if minIndex >= 1 then
		for i = #acceptedQueue - count + 1, #acceptedQueue do
			local questId = acceptedQueue[i]
			local questInfo = questieDb.GetQuest(questId)
			local name = "Unknown"
			if questInfo then
				name = questInfo.name
			end
			if table.contains(list, questId) then
				print("quest " .. questId .. " (" .. name .. ") already set to " .. label)
			else
				self:setQuestCategory(questId, label)
				print("adding quest " .. questId .. " (" .. name .. ") as " .. label)
			end
		end
	else
		print("not enough quests")
	end
end

function addon:updateGroupList()
	local groupList, order = {}, {}
	for category, _ in pairs(self.db.profile.questTable) do
		groupList[category] = category
	end
	for category, _ in pairs(addon.questTable) do
		groupList[category] = category
	end
	
	for category, _ in pairs(groupList) do
		table.insert(order, category)
	end
	table.sort(order)
	
	groupList["Add New..."] = "Add New..."
	table.insert(order, "Add New...")
	
	self.groupList = groupList
	self.groupListOrder = order
end

function addon:onChooseQuestCategory(questId, key)
	if key == "Add New..." then
		StaticPopupDialogs["DAILY_GRIND_ADD"] = {
			text = "Add new category name",
			button1 = "Accept",
			button2 = "Cancel",
			OnAccept = function(dialog)
				local text = dialog.editBox:GetText()
				if text and text ~= "" then
					local questTable = self.db.profile.questTable
					questTable[text] = {}
					self:updateGroupList()
				end
			end,
			timeout = 0,
			hideOnEscape = true,
			whileDead = true,
			hasEditBox = true
		}
		StaticPopup_Show("DAILY_GRIND_ADD")
	else
		self:setQuestCategory(questId, key)
	end
end

local function arrayRemoveElement(array, element)
	local targetIndex = -1
	for i, item in ipairs(array) do
		if item == element then
			targetIndex = i
			break
		end
	end
	if targetIndex > 1 then
		table.remove(array, targetIndex)
	end
end

function addon:setQuestCategory(questId, target)
	local questTable = self.db.profile.questTable
	local added = false
	for category, list in pairs(questTable) do
		if category == target and not table.contains(list, questId) then
			table.insert(list, questId)
			added = true
		elseif category ~= target and table.contains(list, questId) then
			arrayRemoveElement(list, questId)
		end
	end
	
	if not added and not questTable[target] then
		questTable[target] = {questId}
	end
end

function addon:validateTables()
	local seen = {}
	for category, content in pairs(addon.questTable) do
		for _, id in ipairs(content) do
			if seen[id] then
				print("duplicated "..id)
			else
				seen[id] = true
			end
		end
	end
end