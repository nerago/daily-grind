local gui = LibStub("AceGUI-3.0")
local libDB = LibStub("AceDB-3.0")

local addon = LibStub("AceAddon-3.0"):NewAddon("DailyGrind", "AceEvent-3.0", "AceConsole-3.0")

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
	end)
	
	local data = self:buildData();
	
	local tree = gui:Create("TreeGroup")
	tree:SetTree(data)
	tree:SetTreeWidth(300, true)
	tree:SetCallback("OnGroupSelected", function(...) addon:nodeSelected(...) end)
	frame:AddChild(tree)
	
	local content = gui:Create("SimpleGroup")
	content:SetLayout("List")
	local label = gui:Create("Label")
	content:AddChild(label)
	local buttonGo = gui:Create("Button")
	buttonGo:SetText("Map")
	buttonGo:SetWidth(100)
	buttonGo:SetCallback("OnClick", function(...) addon:buttonGoClick(...) end)
	buttonGo:SetDisabled(true)
	content:AddChild(buttonGo)
	
	tree:AddChild(content)
	
	self.label = label
	self.buttonGo = buttonGo
	
	DAILY_GRID_MAIN_FRAME = frame.frame
	tinsert(UISpecialFrames, "DAILY_GRID_MAIN_FRAME")
	
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
	
	local resultData = {}
	for _, zoneName in ipairs(zoneNameList) do
		local zoneQuests = dataByZone[zoneName]
		self:sortQuests(zoneQuests)
		
		local headerText = self:headerFor(zoneName, zoneQuests);
		
		local header = { text = headerText, value = zoneName, children = zoneQuests }
		table.insert(resultData, header)
	end
	return resultData
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

function addon:UpdateActiveQuests()
	-- todo
end

function addon:acceptQuest(eventName, questLogIndex, questId)
	local acceptedQueue = self.acceptedQueue
	table.insert(acceptedQueue, questId) -- todo limits
end

function addon:OnInitialize()
	self:RegisterChatCommand("daily", "slashCommand")
	self:RegisterEvent("QUEST_ACCEPTED", "acceptQuest")
	self:RegisterEvent("QUEST_REMOVED", "UpdateActiveQuests")
	self:RegisterEvent("QUEST_TURNED_IN", "UpdateActiveQuests")
	
	local defaults = { profile = { 
		minimap = {}, 
		questTable = {},
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
			if table.contains(list, questId) then
				print("quest " .. questId .. " already set to " .. label)
			else
				table.insert(list, questId)
				print("adding quest " .. questId .. " as " .. label)
			end
		end
	else
		print("not enough quests")
	end
end





--
-- IsQuestCompletable
-- QuestIsDaily QuestIsWeekly
-- C_QuestLog.GetAllCompletedQuestIDs
-- C_QuestLog.GetMaxNumQuests
-- C_QuestLog.GetMaxNumQuestsCanAccept
-- C_QuestLog.GetQuestIDForLogIndex
-- C_QuestLog.GetHeaderIndexForQuest
-- C_QuestLog.GetInfo (details but active only)
-- numShownEntries, numQuests = C_QuestLog.GetNumQuestLogEntries()
--
-- /run for a,b in pairs(LibStub("AceAddon-3.0"):GetAddon("DailyGrind").quests) do print(b,C_QuestLog.IsQuestFlaggedCompleted(b)) end
-- /run for a,b in pairs(LibStub("AceAddon-3.0"):GetAddon("DailyGrind").quests) do if C_QuestLog.IsQuestFlaggedCompleted(b) then print(b) end end
--
-- C_QuestLog.GetQuestInfo(29211) (title)
-- C_QuestLog.IsQuestFlaggedCompleted(29211)
-- C_QuestLog.GetDistanceSqToQuest
-- 
-- /dump QuestieLoader:ImportModule("QuestieDB")
-- /dump QuestieLoader:ImportModule("QuestieDB").GetQuest(29211)
-- /dump QuestieLoader:ImportModule("QuestieDB").GetQuest(29211).zoneOrSort

-- /dump QuestieLoader:ImportModule("QuestieDB").IsDoable(31852)

--    local sortedQuestIds, questDetails = TrackerUtils:GetSortedQuestIds()
--            local zoneName = questDetails[questId].zoneName
--			TrackerUtils:GetZoneNameByID

--  /dump QuestieLoader:ImportModule("TrackerUtils").GetZoneNameByID(-379)
-- /dump QuestieLoader:ImportModule("TrackerUtils"):GetCategoryNameByID(-379)

-- /dump LibStub("AceAddon-3.0"):GetAddon("DailyGrind").db.profile.questTable


