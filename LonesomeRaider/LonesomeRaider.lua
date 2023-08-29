print("<<<<<<<<<<< Lonsome Raider >>>>>>>>>>")

-- we want to filter out LFM/LFG like messages
-- that means that e.g.
-- LFM ICC10norm heal dps
-- {
--	type: LFM,
--	instance: ICC,
--	size: 10,
--	mode: normal
--	searching: [heal, dps],
--	seen: <timestamp>,
--	source: <sending user>
-- }

-- initial defaults
-- global LSR_SEARCHES holds all found search requests
local LSR_SEARCHES = {}
local LSR_shown = true
local LSR_FILTERTYPE = 2
local LSR_HIGHLIGHTUSER = ""
-- retired
-- local LSR_MAXAGE = 120
-- local LSR_SEARCHTEXT = ""
-- local LSR_EXCLUDETEXT = ""

-- matching message LSR_TYPES
local LSR_TYPES = {
	"UNKNOWN",	-- 1
	"LFM",		-- 2
	"LFG",		-- 3
	"WTS",		-- 4
	"WTB",		-- 5
	"GUILD"		-- 6
}
local LSR_PATTERN = {
	GUILD = {
		"guild"
	},
	WTB = {
		"wtb"
	},
	WTS = {
		"wts"
	},
	LFG = {
		"lfg"
	},
	LFM = {
		"lfm",
		"lf.*for",
		"tank.*for",
		"heal.*for",
		"dps.*for",
		"lf.*tank",
		"lf.*heal",
		"lf.*dps",
		"lf.*all",
		"need.*tank",
		"need.*heal",
		"need.*dps",
		"need.*all",
		"need.*for"
	},
	UNKNOWN = {}
}
function lsr_parse_get_message_type_idx(lowermsg)
	for typecount = 1, #LSR_TYPES do
		for k, v in pairs(LSR_PATTERN[LSR_TYPES[typecount]]) do
			if string.match(lowermsg, v) then
				return typecount;
			end
		end
	end
	return 0;
end

function lsr_parse(message, sender, ret)
	local lowermsg = string.lower(message)
	ret["type"] = lsr_parse_get_message_type_idx(lowermsg)
	ret["timestamp"] = time()
	ret["raw"] = message
	ret["rawtotal"] = sender .. " " .. message
	ret["sender"] = sender
end

function lsr_debug(msg)
	-- print(msg);
end

--
--
--
-- UI
--
--
--

local lsr_OnMouseDown = function(self, button)
	if button == "LeftButton" then
		self:StartMoving()
		self.isMoving = true
		self.hasMoved = false
	elseif button == "RightButton" then
		self:StartSizing()
		self.isMoving = true
		self.hasMoved = false
	end
end

function lsr_OnMouseUp(self)
	if ( self.isMoving ) then
		self:StopMovingOrSizing();
		self.isMoving = false;
		self.hasMoved = true;
	end
end

function lsr_OnHide(self)
	if ( self.isMoving ) then
		self:StopMovingOrSizing();
		self.isMoving = false;
	end
end

function lsr_highlightEntry(cur)
	local entry_frame = cur["listentry"];
	entry_frame.WhisperButton:LockHighlight()
end

function lsr_frameAddTooltip(frame, line1, line2, line3)
	frame:SetScript("OnEnter", function(self, motion)
	    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	    GameTooltip:ClearLines()
	    if line1 then GameTooltip:AddLine(line1) end
	    if line2 then GameTooltip:AddLine(line2) end
	    if line3 then GameTooltip:AddLine(line3) end
	    GameTooltip:Show()
	end)
	frame:SetScript("OnLeave", function(self, motion)
	    GameTooltip:Hide()
	end)
end

-- y=-10
-- x=150
function lsr_addInputCheckBox(parentFrame, title, x, y, initvalue, change_callback)
	local titleFontString = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	titleFontString:SetJustifyH("CENTER")
	titleFontString:SetJustifyV("TOP")
	titleFontString:SetPoint("TOPLEFT", x, y)
	titleFontString:SetText(title)

	local myCheckButton = CreateFrame("CheckButton", nil, parentFrame, "UICheckButtonTemplate")
	myCheckButton:SetPoint("TOPLEFT", 5+x+(strlen(title)*5), y+5)
	myCheckButton:SetChecked(initvalue);
	myCheckButton:HookScript("OnClick", change_callback);
	lsr_debug("created checkbox");
	return myCheckButton;
end

function lsr_addInput(parentFrame, title, x, y, defaulttext, change_callback)
	local searchText = parentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	searchText:SetJustifyH("CENTER")
	searchText:SetJustifyV("TOP")
	searchText:SetPoint("TOPLEFT", x, y)
	searchText:SetText(title)
	local searchBox = CreateFrame("EditBox", title, parentFrame, "InputBoxTemplate")
	local xoffsetInput = x+45;
	local yoffsetInput = y+5;
	searchBox:SetPoint("TOPLEFT", xoffsetInput, yoffsetInput)
	searchBox:SetFrameStrata("DIALOG")
	searchBox:SetBackdropBorderColor(0,255,0)
	searchBox:SetFontObject("ChatFontNormal")
	searchBox:SetAutoFocus(false)
	searchBox:SetWidth(50)
	searchBox:SetHeight(20)
	searchBox:SetText(defaulttext)
	searchBox:SetScript( "OnTextChanged", change_callback)
	searchBox:SetScript( "OnEnterPressed", function(self)
		lsr_redraw()
		self:ClearFocus()
	end)
	return searchBox;
end

local LSR_LOADED=false;
function lsr_addon_loaded(cb)
	lsr_debug("creating dummy frame");
	local f = CreateFrame("Frame", "dummyFrameForAddonLoad", UIParent)
	f:SetScript("OnEvent", function(event, arg1)
		lsr_debug("got event!");
		lsr_debug(event);
		lsr_debug(arg1);

		if(LSR_LOADED) then
			return;
		end

		LSR_LOADED=true;
		if arg1 == "ADDON_LOADED" then
			lsr_debug("event! - addon loaded");
			if LSRConfig == nil then
				LSRConfig = {
					LSR_MAXAGE = 120,
					LSR_SEARCHTEXT = "",
					LSR_EXCLUDETEXT = "",
					LSR_DOSOUND = false
				}
			end
			cb();
			return;
		end
	end);

	f:RegisterEvent("ADDON_LOADED"); -- Fired when saved variables are loaded
	f:RegisterEvent("PLAYER_LOGOUT"); -- Fired when about to log out
end

function lsr_createFrame()
	local backdrop = {
		bgFile = "Interface/BUTTONS/WHITE8X8",
		edgeFile = "Interface/GLUES/Common/Glue-Tooltip-Border",
		tile = true,
		edgeSize = 8,
		tileSize = 8,
		insets = {
			left = 5,
			right = 5,
			top = 5,
			bottom = 5,
		},
	}

	local initwidht = 500
	local initheight = 300

	local f = CreateFrame("Frame", "aLSRMainFrame", UIParent)
	f:EnableMouse(true);
	f:SetMovable(true);
	f:SetScript("OnMouseDown",lsr_OnMouseDown);
	f:SetScript("OnMouseUp",lsr_OnMouseUp);
	f:SetScript("OnHide",lsr_OnHide);
	f:SetResizable(true)
	f:SetSize(initwidht, initheight) -- initial size
	f:SetPoint("CENTER")
	f:SetFrameStrata("BACKGROUND")
	f:SetBackdrop(backdrop)
	-- f:SetBackdropColor(0, 0, 0, 0.75)
	f:SetBackdrop({bgFile = "Interface/TutorialFrame/TutorialFrameBackground", 
	                                            edgeFile = "Interface/Tooltips/UI-Tooltip-Border", 
	                                            tile = true, tileSize = 16, edgeSize = 16, 
	                                            insets = { left = 4, right = 4, top = 4, bottom = 4 }});

	local fontStringTitle = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fontStringTitle:SetJustifyH("CENTER")
	fontStringTitle:SetJustifyV("TOP")
	fontStringTitle:SetPoint("TOPLEFT", 10, -10)
	fontStringTitle:SetText("<<<Lonesome Raider>>>")
	f.Title = fontStringTitle

	local inputElementSearch = lsr_addInput(f, "Search", 150, -10, _G.LSRConfig.LSR_SEARCHTEXT, function(self) 
		_G.LSRConfig.LSR_SEARCHTEXT = string.lower(self:GetText())
	end);
	lsr_frameAddTooltip(inputElementSearch, "Only show messages containing given text: space separated requires every word to be in the message")

	local inputElementExclude = lsr_addInput(f, "Exclude", 260, -10, _G.LSRConfig.LSR_EXCLUDETEXT, function(self) 
		_G.LSRConfig.LSR_EXCLUDETEXT = string.lower(self:GetText())
	end);
	lsr_frameAddTooltip(inputElementExclude, "Exclude messages containing given text")

	local inputElementMaxAge = lsr_addInput(f, "Max age", 360, -10, tostring(_G.LSRConfig.LSR_MAXAGE), function(self) 
		_G.LSRConfig.LSR_MAXAGE = tonumber(string.lower(self:GetText()));
	end);
	lsr_frameAddTooltip(inputElementMaxAge, "Entries disappear after n seconds")

	local inputElementDoSound = lsr_addInputCheckBox(f, "play sound", 460, -10, _G.LSRConfig.LSR_DOSOUND, function(self) 
		_G.LSRConfig.LSR_DOSOUND = self:GetChecked()
	end);
	lsr_frameAddTooltip(inputElementDoSound, "Play a sound when new messages arrive")


	local fontStringStats = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	fontStringStats:SetJustifyH("CENTER")
	fontStringStats:SetJustifyV("TOP")
	fontStringStats:SetPoint("TOPLEFT", 600, -10)
	fontStringStats:SetText("")
	-- hide chatters count
	fontStringStats:Hide()
	f.Stats = fontStringStats

	-- f.SearchInputBox = searchBox


	f.Close = CreateFrame("Button", "$parentClose", f)
	lsr_frameAddTooltip(f.Close, "Close")
	f.Close:SetSize(24, 24)
	f.Close:SetPoint("TOPRIGHT")
	f.Close:SetNormalTexture("Interface/Buttons/UI-Panel-MinimizeButton-Up")
	f.Close:SetPushedTexture("Interface/Buttons/UI-Panel-MinimizeButton-Down")
	f.Close:SetHighlightTexture("Interface/Buttons/UI-Panel-MinimizeButton-Highlight", "ADD")
	f.Close:SetScript("OnClick", function(self)
		LSR_shown = false;
		self:GetParent():Hide()
	end)

	f.Clear = CreateFrame("Button", nil, f)
	lsr_frameAddTooltip(f.Clear, "Clear")
	f.Clear:SetSize(24, 24)
	f.Clear:SetPoint("TOPRIGHT", -20, 0)
	f.Clear:SetNormalTexture("Interface/Buttons/UI-Panel-QuestHideButton-disabled")
	f.Clear:SetScript("OnClick", function(self)
		for k,v in pairs(LSR_SEARCHES) do
			local cur = LSR_SEARCHES[k]
			cur["listentry"]:Hide()
		end
		LSR_SEARCHES = {}
		lsr_debug("clear")
	end)

	f.SF = CreateFrame("ScrollFrame", "$parent_DF", f, "UIPanelScrollFrameTemplate")
	f.SF:SetPoint("TOPLEFT", f, 12, -30)
	f.SF:SetPoint("BOTTOMRIGHT", f, -30, 10)

	local scrolled_frame = CreateFrame("Frame", nil, f)
	scrolled_frame:SetPoint("TOPLEFT", f.SF)
	scrolled_frame:SetPoint("BOTTOMRIGHT", f.SF)
	scrolled_frame:SetBackdropColor(1, 1, 1)
	scrolled_frame:SetSize(100, 100) -- initial size
	f.scrolled_frame = scrolled_frame;
	f.SF:SetScrollChild(scrolled_frame)
	return f;
end

local _MainWindow = nil
function lsr_getFrame()
	if _MainWindow == nil then
		_MainWindow = lsr_createFrame()
	end
	return _MainWindow
end

local STATS = {
	ChatUsers = 0
}
function lsr_createEntryFrame()
	local MainWindow = lsr_getFrame()
	local entry_frame = CreateFrame("Frame", nil, MainWindow.scrolled_frame)
	entry_frame:SetBackdropColor(1, 1, 1)
	entry_frame:SetSize(400, 400)

	entry_frame.WhisperButton = CreateFrame("Button", nil, entry_frame, "UIPanelButtonTemplate")
	entry_frame.WhisperButton:SetSize(100 ,22) -- width, height
	entry_frame.WhisperButton:SetPoint("TOPLEFT", entry_frame, 0, 5)
	lsr_frameAddTooltip(entry_frame.WhisperButton, "Start whisper player")
	entry_frame.WhisperButton:SetScript("OnClick", function(self)
		print("Subject:"..self.Subject)
		ChatEdit_ActivateChat(DEFAULT_CHAT_FRAME.editBox, 0)
		DEFAULT_CHAT_FRAME.editBox:SetFocus()
		DEFAULT_CHAT_FRAME.editBox:SetText("/w "..self.Sender.." ")
		LSR_HIGHLIGHTUSER = self.Sender
	end)

	entry_frame.Timestamp = entry_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	entry_frame.Timestamp:SetPoint("TOPLEFT", entry_frame, 100, 0)
	entry_frame.Timestamp:SetText("0s")

	entry_frame.Text = entry_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	entry_frame.Text:SetPoint("TOPLEFT", entry_frame, 125, 0)
	entry_frame.Text:SetText("init")

	return entry_frame;
end

local function lsr_isEmpty(s)
  return s == nil or s == ''
end

function lsr_stringPatternMatch(haystack, needles)
	for pattern in string.gmatch(needles, "[^%s]+") do
		if not string.find(haystack,pattern) then
			return false;
		end
	end
	return true;
	-- return  string.find(lowermsg," " .. LSR_EXCLUDETEXT .. " ");
end

-- return true if should be shown
function lsr_filter(cur)
	if LSR_FILTERTYPE ~= -1 then
		if cur["type"] ~= LSR_FILTERTYPE then
			-- print("type is not "..LSR_FILTERTYPE)
			return false
		end
	end

	local lowermsg = string.lower(cur["rawtotal"])
	if not lsr_isEmpty(_G.LSRConfig.LSR_EXCLUDETEXT) and lsr_stringPatternMatch(lowermsg, _G.LSRConfig.LSR_EXCLUDETEXT) then
		return false;
	end
	if not lsr_isEmpty(_G.LSRConfig.LSR_SEARCHTEXT) and not lsr_stringPatternMatch(lowermsg,_G.LSRConfig.LSR_SEARCHTEXT) then
		return false;
	end
	return true
end

function lsr_timestampSetColor(tsFontString, age)
	if age < 10 then
		tsFontString:SetTextColor(0, 1, 0, 1)
		return
	end
	if age < 30 then
		tsFontString:SetTextColor(0, 0.5, 0, 1)
		return
	end

	-- old
	tsFontString:SetTextColor(1, 0, 0, 1)
end

function lsr_redraw()
	-- render each of the entries, or update its position/text
	local MainWindow = lsr_getFrame()
	MainWindow.Stats:SetText(STATS.ChatUsers.." active chatters");
	local iter = 0;
	local current_timestamp = time();
	for k,v in pairs(LSR_SEARCHES) do
		local cur = LSR_SEARCHES[k]
		local age = current_timestamp - cur["timestamp"]


		if cur["listentry"] == nil then
			cur["listentry"] = lsr_createEntryFrame()
		end

		if age > _G.LSRConfig.LSR_MAXAGE then
			LSR_SEARCHES[k]=nil;
			cur["listentry"]:Hide()
		else
			if lsr_filter(cur) then
				if not lsr_isEmpty(LSR_HIGHLIGHTUSER) and cur.sender == LSR_HIGHLIGHTUSER then
					lsr_highlightEntry(cur);
				end

				if age < 1 then
					if _G.LSRConfig.LSR_DOSOUND then
						PlaySound("QUESTADDED", "master");
						-- PlaySound("HumanFemaleWarriorNPCGreeting05", "master");
					end
				end


				cur["listentry"]:Show()
				cur["listentry"]:ClearAllPoints()
				cur["listentry"]:SetPoint("TOPLEFT", MainWindow.scrolled_frame, 5, -22*iter)
				cur["listentry"]:SetPoint("BOTTOMRIGHT", MainWindow.scrolled_frame)

				cur["listentry"].Timestamp:SetText(age .. "s")
				lsr_timestampSetColor(cur["listentry"].Timestamp, age);
				cur["listentry"].Text:SetText(cur["raw"])
				cur["listentry"].WhisperButton:SetText(cur["sender"])
				cur["listentry"].WhisperButton.Sender=cur["sender"]
				cur["listentry"].WhisperButton.Subject=cur["raw"]

				iter = iter + 1
			else
				cur["listentry"]:Hide()
			end
		end
	end
end

function lsr_setupChatHooks()
	local LSR_ONUPDATE_INTERVAL = 2
	local LSR_TimeSinceLastUpdate = 0
	local LSR_ChatHookFrame = CreateFrame("Frame")
	LSR_ChatHookFrame:SetScript("OnUpdate", function(self, elapsed)
		LSR_TimeSinceLastUpdate = LSR_TimeSinceLastUpdate + elapsed
		if LSR_TimeSinceLastUpdate >= LSR_ONUPDATE_INTERVAL then
			LSR_TimeSinceLastUpdate = 0
			lsr_redraw()
		end
	end)
	LSR_ChatHookFrame:SetScript("OnShow", function(self)
		LSR_TimeSinceLastUpdate = 0
	end)
	LSR_ChatHookFrame:RegisterEvent("CHAT_MSG_CHANNEL")
	LSR_ChatHookFrame:RegisterEvent("CHAT_MSG_SAY")
	LSR_ChatHookFrame:RegisterEvent("CHAT_MSG_YELL")
	LSR_ChatHookFrame:SetScript("OnEvent", function(self, event, message, sender)
		lsr_debug("msg event: "..message.." {from:}"..sender);
		if LSR_SEARCHES[sender] == nil then
			STATS.ChatUsers = STATS.ChatUsers + 1;
			LSR_SEARCHES[sender] = {}
		end
	
		lsr_parse(message, sender, LSR_SEARCHES[sender]);
	
		lsr_redraw()
	end)
end

function lsr_toggleWindow()
	lsr_debug("toggle lsr_main win");
	local MainWindow = lsr_getFrame()
	if LSR_shown then
		MainWindow:Hide()
		LSR_shown = false
	else
		MainWindow:Show()
		LSR_shown = true
	end
end

function lsr_main()
	SLASH_LonesomeRaider1 = "/lsr"
	SlashCmdList["LonesomeRaider"] = lsr_toggleWindow
	lsr_setupChatHooks();

	lsr_toggleWindow()
end

lsr_addon_loaded(function(self)
	lsr_debug("addon loaded!");
	lsr_main();
	-- lsr_getFrame() --init after addon loaded
end)

