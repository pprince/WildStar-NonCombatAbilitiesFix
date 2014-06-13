-----------------------------------------------------------------------------------------------
-- Client Lua Script for NonCombatAbilitiesFix
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Window"
require "Spell"
require "GameLib"
require "AbilityBook"
require "PlayerPathLib"

-----------------------------------------------------------------------------------------------
-- NonCombatAbilitiesFix Module Definition
-----------------------------------------------------------------------------------------------
local NonCombatAbilitiesFix = {}

-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------

local karTabTypes =
{
	Mount = 1,
	Misc = 2,
	Cmd = 3
}

local karTabDragDropType =
{
	[karTabTypes.Mount] = "DDNonCombat",
	[karTabTypes.Misc] = "DDNonCombat",
	[karTabTypes.Cmd] = "DDGameCommand"
}

local ktCommandIds =
{
	GameLib.CodeEnumGameCommandType.GadgetAbility,
	GameLib.CodeEnumGameCommandType.DefaultAttack,
	GameLib.CodeEnumGameCommandType.ClassInnateAbility,
	GameLib.CodeEnumGameCommandType.ActivateTarget,
	GameLib.CodeEnumGameCommandType.FollowTarget,
	GameLib.CodeEnumGameCommandType.Sprint,
	GameLib.CodeEnumGameCommandType.ToggleWalk,
	GameLib.CodeEnumGameCommandType.Dismount,
	GameLib.CodeEnumGameCommandType.Vacuum,
	GameLib.CodeEnumGameCommandType.PathAction,
	GameLib.CodeEnumGameCommandType.ToggleScannerBot,
	GameLib.CodeEnumGameCommandType.Interact,
	GameLib.CodeEnumGameCommandType.DashForward,
	GameLib.CodeEnumGameCommandType.DashBackward,
	GameLib.CodeEnumGameCommandType.DashLeft,
	GameLib.CodeEnumGameCommandType.DashRight
}

-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function NonCombatAbilitiesFix:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self

	o.arLists =
	{
		[karTabTypes.Mount] = {},
		[karTabTypes.Misc] = {},
		[karTabTypes.Cmd] = {}
	}
	o.nSelectedTab = karTabTypes.Cmd

    return o
end

function NonCombatAbilitiesFix:Init()
    Apollo.RegisterAddon(self)
end

-----------------------------------------------------------------------------------------------
-- NonCombatAbilitiesFix OnLoad
-----------------------------------------------------------------------------------------------
function NonCombatAbilitiesFix:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("NonCombatAbilitiesFix.xml")
	self.xmlDoc:RegisterCallback("OnDocumentReady", self) 
end

function NonCombatAbilitiesFix:OnDocumentReady()
	if self.xmlDoc == nil then
		return
	end
	
	Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", 	"OnInterfaceMenuListHasLoaded", self)
	Apollo.RegisterEventHandler("WindowManagementReady", 		"OnWindowManagementReady", self)
	
	Apollo.RegisterEventHandler("GenericEvent_OpenNonCombatAbilitiesFix", "OnNonCombatAbilitiesFixOn", self)
	Apollo.RegisterEventHandler("AbilityBookChange", "OnAbilityBookChange", self)
	
	-- load our forms
	self.wndMain = Apollo.LoadForm(self.xmlDoc, "NonCombatAbilitiesFixForm", nil, self)
	self.wndMain:Show(false)
	
	self.wndEntryContainer = self.wndMain:FindChild("EntriesContainer")
	self.wndEntryContainerMounts = self.wndMain:FindChild("EntriesContainerMounts")
	self.wndEntryContainerMisc = self.wndMain:FindChild("EntriesContainerMisc")
	self.wndTabsContainer = self.wndMain:FindChild("TabsContainer")
	self.wndTabsContainer:FindChild("BankTabBtnMounts"):SetData(karTabTypes.Mount)
	self.wndTabsContainer:FindChild("BankTabBtnMisc"):SetData(karTabTypes.Misc)
	self.wndTabsContainer:FindChild("BankTabBtnCmd"):SetData(karTabTypes.Cmd)
end

function NonCombatAbilitiesFix:OnWindowManagementReady()
	Event_FireGenericEvent("WindowManagementAdd", {wnd = self.wndMain, strName = Apollo.GetString("InterfaceMenu_NonCombatAbilities")})
end

function NonCombatAbilitiesFix:OnInterfaceMenuListHasLoaded()
	Event_FireGenericEvent("InterfaceMenuList_NewAddOn", Apollo.GetString("InterfaceMenu_NonCombatAbilities"), {"GenericEvent_OpenNonCombatAbilitiesFix", "", "Icon_Windows32_UI_CRB_InterfaceMenu_NonCombatAbility"})
end

function NonCombatAbilitiesFix:OnAbilityBookChange()
	if self.wndMain == nil or not self.wndMain:IsShown() then
		return
	end
	
	self:Redraw()
end

function NonCombatAbilitiesFix:OnNonCombatAbilitiesFixOn()
	self.nSelectedTab = self.nSelectedTab or karTabTypes.Cmd
	self:Redraw()
	self.wndMain:Show(true)
	self.wndMain:ToFront()
end

function NonCombatAbilitiesFix:Redraw()
	local unitPlayer = GameLib.GetPlayerUnit()
	
	if not unitPlayer then
		return
	end
	
	self.arLists[karTabTypes.Mount] = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Mount) or {}
	self.arLists[karTabTypes.Misc] = AbilityBook.GetAbilitiesList(Spell.CodeEnumSpellTag.Misc) or {}
	self.arLists[karTabTypes.Cmd] = {}

	local ePlayerPath = GameLib.GetPlayerUnit():GetPlayerPathType()
	
	for idx, id in ipairs(ktCommandIds) do
		local bSkip = false
		if id == GameLib.CodeEnumGameCommandType.ToggleScannerBot then
			bSkip = ePlayerPath ~= PlayerPathLib.PlayerPathType_Scientist
		end
	
		if not bSkip then
			self.arLists[karTabTypes.Cmd][idx] = GameLib.GetGameCommand(id)
		end
	end

	self:ShowTab()
end

function NonCombatAbilitiesFix:ShowTab()
	self.wndEntryContainer:DestroyChildren()
	self.wndEntryContainerMounts:DestroyChildren()
	self.wndEntryContainerMisc:DestroyChildren()
			
	self.wndEntryContainer:Show(self.nSelectedTab == karTabTypes.Cmd)
	self.wndEntryContainerMisc:Show(self.nSelectedTab == karTabTypes.Misc)
	self.wndEntryContainerMounts:Show(self.nSelectedTab == karTabTypes.Mount)

	for idx, tData in pairs(self.arLists[self.nSelectedTab]) do
		if self.nSelectedTab == karTabTypes.Mount and tData.bIsActive then
			self:HelperCreateMountEntry(tData)
		elseif self.nSelectedTab == karTabTypes.Misc and tData.bIsActive then
			self:HelperCreateMiscEntry(tData)
		elseif self.nSelectedTab == karTabTypes.Cmd then
			self:HelperCreateGameCmdEntry(tData)
		end
	end

	local function SortFunction(a,b)
		local aData = a and a:GetData()
		local bData = b and b:GetData()
		if not aData and not bData then
			return true
		end
		return (aData.strName or aData.strName) < (bData.strName or bData.strName)
	end

	self.wndEntryContainer:ArrangeChildrenVert(0, SortFunction(a,b))
	self.wndEntryContainerMounts:ArrangeChildrenVert(0, SortFunction(a,b))
	self.wndEntryContainerMisc:ArrangeChildrenVert(0, SortFunction(a,b))
	self.wndEntryContainer:SetText(#self.wndEntryContainer:GetChildren() == 0 and Apollo.GetString("NCSpellbook_NoResultsAvailable") or "")
	self.wndEntryContainerMounts:SetText(#self.wndEntryContainerMounts:GetChildren() == 0 and Apollo.GetString("NCSpellbook_NoResultsAvailable") or "")
	self.wndEntryContainerMisc:SetText(#self.wndEntryContainerMisc:GetChildren() == 0 and Apollo.GetString("NCSpellbook_NoResultsAvailable") or "")

	
	for idx, wndTab in pairs(self.wndTabsContainer:GetChildren()) do
		wndTab:SetCheck(self.nSelectedTab == wndTab:GetData())
	end
end

function NonCombatAbilitiesFix:HelperCreateMountEntry(tData)
	local wndEntry = Apollo.LoadForm(self.xmlDoc, "MountEntry", self.wndEntryContainerMounts, self)
	wndEntry:SetData(tData)

	wndEntry:FindChild("Title"):SetText(tData.strName)
	wndEntry:FindChild("ActionBarButton"):SetContentId(tData.nId)
	wndEntry:FindChild("ActionBarButton"):SetData(tData.nId)
	wndEntry:FindChild("ActionBarButton"):SetSprite(tData.tTiers[tData.nCurrentTier].splObject:GetIcon())
	wndEntry:FindChild("MountPreviewBtn"):SetData(tData)

	if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetSpellTooltipForm(self, wndEntry, tData.tTiers[tData.nCurrentTier].splObject)
	end
end

function NonCombatAbilitiesFix:HelperCreateMiscEntry(tData)
	local wndEntry = Apollo.LoadForm(self.xmlDoc, "SpellEntry", self.wndEntryContainerMisc, self)
	wndEntry:SetData(tData)

	wndEntry:FindChild("Title"):SetText(tData.strName)
	wndEntry:FindChild("ActionBarButton"):SetContentId(tData.nId)
	wndEntry:FindChild("ActionBarButton"):SetData(tData.nId)
	wndEntry:FindChild("ActionBarButton"):SetSprite(tData.tTiers[tData.nCurrentTier].splObject:GetIcon())

	if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
		Tooltip.GetSpellTooltipForm(self, wndEntry, tData.tTiers[tData.nCurrentTier].splObject)
	end
end

function NonCombatAbilitiesFix:HelperCreateGameCmdEntry(tData)
	local wndEntry = Apollo.LoadForm(self.xmlDoc, "GameCommandEntry", self.wndEntryContainer, self)
	wndEntry:SetData(tData)
	
	wndEntry:FindChild("Title"):SetText(tData.strName)
	wndEntry:FindChild("ActionBarButton"):SetContentId(tData.nGameCommandId)
end

function NonCombatAbilitiesFix:OnClose()
	self.wndMain:Show(false)
end

function NonCombatAbilitiesFix:OnTabBtnCheck(wndHandler, wndControl, eMouseButton)
	self.nSelectedTab = wndControl:GetData()
	self:OnCloseMountPreview()
	self:ShowTab()
end

---------------------------------------------------------------------------------------------------
-- SpellEntry Functions
---------------------------------------------------------------------------------------------------

function NonCombatAbilitiesFix:OnBeginDragDrop(wndHandler, wndControl, x, y, bDragDropStarted)
	if wndHandler ~= wndControl then
		return false
	end
	local wndParent = wndControl:GetParent()

	Apollo.BeginDragDrop(wndParent, karTabDragDropType[self.nSelectedTab], wndParent:FindChild("ActionBarButton"):GetSprite(), wndParent:GetData().nId)

	return true
end

function NonCombatAbilitiesFix:OnGenerateTooltip(wndControl, wndHandler, eType, arg1, arg2)
	if eType == Tooltip.TooltipGenerateType_GameCommand then
		local xml = XmlDoc.new()
		xml:AddLine(arg2)
		wndControl:SetTooltipDoc(xml)
	elseif eType == Tooltip.TooltipGenerateType_Spell then
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, arg1)
		end
	elseif eType == Tooltip.TooltipGenerateType_Default then
		local wndParent = wndControl:GetParent()
		local tData = wndParent:GetData() or {}
		local splMount = GameLib.GetSpell(tData.tTiers[tData.nCurrentTier].nTierSpellId)
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, splMount)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- GameCommandEntry Functions
---------------------------------------------------------------------------------------------------

function NonCombatAbilitiesFix:OnBeginCmdDragDrop(wndHandler, wndControl, x, y, bDragDropStarted)
	if wndHandler ~= wndControl then
		return false
	end
	local wndParent = wndControl:GetParent()
	local tData = wndParent:GetData()

	Apollo.BeginDragDrop(wndParent, karTabDragDropType[self.nSelectedTab], tData.strIcon, tData.nGameCommandId)
	return true
end

function NonCombatAbilitiesFix:OnGenerateGameCmdTooltip(wndControl, wndHandler, eType, arg1, arg2)
	local wndParent = wndControl:GetParent()
	local tData = wndParent:GetData()

	if tData.splAbility ~= nil then
		if Tooltip ~= nil and Tooltip.GetSpellTooltipForm ~= nil then
			Tooltip.GetSpellTooltipForm(self, wndControl, tData.splAbility)
		end
	else
		local xml = XmlDoc.new()
		xml:AddLine(wndParent:GetData().strName)
		wndControl:SetTooltipDoc(xml)
	end
end

---------------------------------------------------------------------------------------------------
-- Mount Functions
---------------------------------------------------------------------------------------------------

function NonCombatAbilitiesFix:OnMountPreviewCheck(wndHandler, wndControl)
	local tMountData = wndHandler:GetData()
	if not tMountData then
		return
	end
	
	local tMountTierData = tMountData.tTiers[tMountData.nCurrentTier]
	if tMountTierData and tMountTierData.nPreviewCreatureId then
		self.wndMain:FindChild("MountPortrait"):SetCostumeToCreatureId(tMountTierData.nPreviewCreatureId)
		self.wndMain:FindChild("MountPortrait"):SetCamera("Paperdoll")
		if tMountTierData.bIsHoverboard then
			self.wndMain:FindChild("MountPortrait"):SetAttachment(PetCustomizationLib.HoverboardAttachmentPoint, tMountTierData.nPreviewHoverboardItemDisplay)
		end
		self.wndMain:FindChild("MountPortrait"):SetModelSequence(150)
		self.wndMain:FindChild("MountPreview"):Show(true)
	end
end

function NonCombatAbilitiesFix:OnCloseMountPreview(wndHandler, wndControl) -- Also from Lua
	if self.nSelectedTab == karTabTypes.Mount then
		for idx, wndCurr in pairs(self.wndEntryContainerMounts:GetChildren()) do
			if wndCurr:FindChild("MountPreviewBtn") then
				wndCurr:FindChild("MountPreviewBtn"):SetCheck(false)
			end
		end
	end
	self.wndMain:FindChild("MountPreview"):Show(false)
end

function NonCombatAbilitiesFix:OnRotateRight()
	self.wndMain:FindChild("MountPortrait"):ToggleLeftSpin(true)
end

function NonCombatAbilitiesFix:OnRotateRightCancel()
	self.wndMain:FindChild("MountPortrait"):ToggleLeftSpin(false)
end

function NonCombatAbilitiesFix:OnRotateLeft()
	self.wndMain:FindChild("MountPortrait"):ToggleRightSpin(true)
end

function NonCombatAbilitiesFix:OnRotateLeftCancel()
	self.wndMain:FindChild("MountPortrait"):ToggleRightSpin(false)
end

local NonCombatAbilitiesFixInst = NonCombatAbilitiesFix:new()
NonCombatAbilitiesFixInst:Init()
