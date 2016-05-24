--[[ Element: Class Icons

 Toggles the visibility of icons depending on the player's class and
 specialization.

 Widget

 ClassIcons - An array consisting of as many UI Textures as the theoretical
 maximum return of `UnitPowerMax`.

 Notes

 Monk    - Chi Orbs
 Paladin - Holy Power
 Priest  - Shadow Orbs
 Warlock - Soul Shards

 Examples

   local ClassIcons = {}
   for index = 1, 6 do
      local Icon = self:CreateTexture(nil, 'BACKGROUND')

      -- Position and size.
      Icon:SetSize(16, 16)
      Icon:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', index * Icon:GetWidth(), 0)

      ClassIcons[index] = Icon
   end

   -- Register with oUF
   self.ClassIcons = ClassIcons

 Hooks

 OverrideVisibility(self) - Used to completely override the internal visibility
                            function. Removing the table key entry will make
                            the element fall-back to its internal function
                            again.
 Override(self)           - Used to completely override the internal update
                            function. Removing the table key entry will make the
                            element fall-back to its internal function again.
 UpdateTexture(element)   - Used to completely override the internal function
                            for updating the power icon textures. Removing the
                            table key entry will make the element fall-back to
                            its internal function again.

]]

local parent, ns = ...
local oUF = ns.oUF
local isBetaClient = select(4, GetBuildInfo()) >= 70000

local _, PlayerClass = UnitClass'player'

-- Holds the class specific stuff.
local ClassPowerID, ClassPowerType
local ClassPowerEnable, ClassPowerDisable
local RequireSpec, RequireSpell

local UpdateTexture = function(element)
	local color = oUF.colors.power[ClassPowerType]
	if(not isBetaClient and ClassPowerType == 'COMBO_POINTS') then
		-- COMBO_POINTS don't have a color pre-Legion so we need to supply that color
		color = {1, 0.96, 0.41}
	end

	for i = 1, #element do
		local icon = element[i]
		if(icon.SetDesaturated) then
			icon:SetDesaturated(PlayerClass ~= 'PRIEST')
		end

		icon:SetVertexColor(color[1], color[2], color[3])
	end
end

local Update = function(self, event, unit, powerType)
	if(unit ~= 'player' or powerType ~= ClassPowerType) then
		return
	end

	local element = self.ClassIcons

	--[[ :PreUpdate()

	 Called before the element has been updated

	 Arguments

	 self  - The ClassIcons element
	 event - The event, that the update is being triggered for
	]]
	if(element.PreUpdate) then
		element:PreUpdate(event)
	end

	local cur, max, oldMax
	if(event ~= 'ClassPowerDisable') then
		cur = UnitPower('player', ClassPowerID)
		max = UnitPowerMax('player', ClassPowerID)

		for i = 1, max do
			if(i <= cur) then
				element[i]:Show()
			else
				element[i]:Hide()
			end
		end

		oldMax = element.__max
		if(max ~= oldMax) then
			if(max < oldMax) then
				for i = max + 1, oldMax do
					element[i]:Hide()
				end
			end

			element.__max = max
		end
	end
	--[[ :PostUpdate(cur, max, hasMaxChanged, event)

	 Called after the element has been updated

	 Arguments

	 self          - The ClassIcons element
	 cur           - The current amount of power
	 max           - The maximum amount of power
	 hasMaxChanged - Shows if the maximum amount has changed since the last
	                 update
	 event         - The event, which the update happened for
	]]
	if(element.PostUpdate) then
		return element:PostUpdate(cur, max, oldMax ~= max, event)
	end
end

local function Visibility(self, event, unit)
	local element = self.ClassIcons
	local shouldEnable

	if(not UnitHasVehicleUI('player')) then
		if(not RequireSpec or RequireSpec == GetSpecialization()) then
			if(not RequireSpell or IsPlayerSpell(RequireSpell)) then
				self:UnregisterEvent('SPELLS_CHANGED', Visibility)
				shouldEnable = true
			else
				self:RegisterEvent('SPELLS_CHANGED', Visibility, true)
			end
		end
	end

	local isEnabled = element.isEnabled
	if(shouldEnable and not isEnabled) then
		ClassPowerEnable(self)
	elseif(not shouldEnable and (isEnabled or isEnabled == nil)) then
		ClassPowerDisable(self)
	end
end

local Path = function(self, ...)
	return (self.ClassIcons.Override or Update) (self, ...)
end

local VisibilityPath = function(self, ...)
	return (self.ClassIcons.OverrideVisibility or Visibility) (self, ...)
end

local ForceUpdate = function(element)
	return VisibilityPath(element.__owner, 'ForceUpdate', element.__owner.unit)
end

do
	ClassPowerEnable = function(self)
		self:RegisterEvent('UNIT_DISPLAYPOWER', Path)
		self:RegisterEvent('UNIT_POWER_FREQUENT', Path)
		Path(self, 'ClassPowerEnable', 'player', ClassPowerType)
		self.ClassIcons.isEnabled = true
	end

	ClassPowerDisable = function(self)
		self:UnregisterEvent('UNIT_DISPLAYPOWER', Path)
		self:UnregisterEvent('UNIT_POWER_FREQUENT', Path)

		local element = self.ClassIcons
		for i = 1, #element do
			element[i]:Hide()
		end

		Path(self, 'ClassPowerDisable', 'player', ClassPowerType)
		self.ClassIcons.isEnabled = false
	end

	if(PlayerClass == 'MONK') then
		ClassPowerID = SPELL_POWER_CHI
		ClassPowerType = "CHI"

		if(isBetaClient) then
			RequireSpec = SPEC_MONK_WINDWALKER
		end
	elseif(PlayerClass == 'PALADIN') then
		ClassPowerID = SPELL_POWER_HOLY_POWER
		ClassPowerType = "HOLY_POWER"

		if(isBetaClient) then
			RequireSpell = 85256 -- Templar's Verdict
		else
			RequireSpell = 85673 -- Word of Glory
		end
	elseif(PlayerClass == 'PRIEST' and not isBetaClient) then
		ClassPowerID = SPELL_POWER_SHADOW_ORBS
		ClassPowerType = "SHADOW_ORBS"
		RequireSpec = SPEC_PRIEST_SHADOW
		RequireSpell = 95740 -- Shadow Orbs
	elseif(PlayerClass == 'WARLOCK') then
		ClassPowerID = SPELL_POWER_SOUL_SHARDS
		ClassPowerType = "SOUL_SHARDS"

		if(not isBetaClient) then
			RequireSpec = SPEC_WARLOCK_AFFLICTION
			RequireSpell = WARLOCK_SOULBURN
		end
	elseif(PlayerClass == 'ROGUE' or PlayerClass == 'DRUID') then
		ClassPowerID = SPELL_POWER_COMBO_POINTS
		ClassPowerType = 'COMBO_POINTS'
	elseif(isBetaClient and PlayerClass == 'MAGE') then
		ClassPowerID = SPELL_POWER_ARCANE_CHARGES
		ClassPowerType = 'ARCANE_CHARGES'
		RequireSpec = SPEC_MAGE_ARCANE
	end
end

local Enable = function(self, unit)
	if(unit ~= 'player' or not ClassPowerID) then return end

	local element = self.ClassIcons
	if(not element) then return end

	element.__owner = self
	element.__max = #element
	element.ForceUpdate = ForceUpdate

	if(RequireSpec) then
		self:RegisterEvent('PLAYER_TALENT_UPDATE', VisibilityPath, true)
	end

	element.ClassPowerEnable = ClassPowerEnable
	element.ClassPowerDisable = ClassPowerDisable

	local isChildrenTextures
	for i = 1, #element do
		local icon = element[i]
		if(icon:IsObjectType'Texture') then
			if(not icon:GetTexture()) then
				icon:SetTexCoord(0.45703125, 0.60546875, 0.44531250, 0.73437500)
				icon:SetTexture([[Interface\PlayerFrame\Priest-ShadowUI]])
			end

			isChildrenTextures = true
		end
	end

	if(isChildrenTextures) then
		(element.UpdateTexture or UpdateTexture) (element)
	end

	return true
end

local Disable = function(self)
	local element = self.ClassIcons
	if(not element) then return end

	ClassPowerDisable(self)
end

oUF:AddElement('ClassIcons', VisibilityPath, Enable, Disable)
