--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/gui/wiviewport.lua")
include("/gui/hbox.lua")
include("/gui/aspectratio.lua")
include("/gui/pfm/button.lua")
include("/gui/pfm/playbutton.lua")
include("/pfm/fonts.lua")

util.register_class("gui.PFMViewport",gui.Base)

gui.PFMViewport.CAMERA_MODE_PLAYBACK = 0
gui.PFMViewport.CAMERA_MODE_FLY = 1
gui.PFMViewport.CAMERA_MODE_WALK = 2
gui.PFMViewport.CAMERA_MODE_COUNT = 3
function gui.PFMViewport:__init()
	gui.Base.__init(self)
end
function gui.PFMViewport:OnInitialize()
	gui.Base.OnInitialize(self)

	local hTop = 37
	local hBottom = 42
	local hViewport = 221
	self:SetSize(512,hViewport +hTop +hBottom)

	self.m_bg = gui.create("WIRect",self,0,0,self:GetWidth(),self:GetHeight(),0,0,1,1)
	self.m_bg:SetColor(Color(38,38,38))

	self.m_vpBg = gui.create("WIRect",self,0,37,self:GetWidth(),hViewport,0,0,1,1)
	self.m_vpBg:SetColor(Color.Black)

	self.m_aspectRatioWrapper = gui.create("WIAspectRatio",self.m_vpBg,0,0,self.m_vpBg:GetWidth(),self.m_vpBg:GetHeight(),0,0,1,1)
	self.m_aspectRatioWrapper:AddCallback("OnAspectRatioChanged",function(el,aspectRatio)
		if(util.is_valid(self.m_viewport)) then
			local scene = self.m_viewport:GetScene()
			if(scene ~= nil) then
				local cam = scene:GetActiveCamera()
				if(cam ~= nil) then
					cam:SetAspectRatio(aspectRatio)
					cam:UpdateMatrices()
				end
			end
		end
		--[[local maxResolution = engine.get_window_resolution()
		local w,h = util.clamp_resolution_to_aspect_ratio(maxResolution.x,maxResolution.y,aspectRatio)
		self.m_viewport:SetupScene(maxResolution.x,maxResolution.y)]]
		--self:Update()
	end)
	self.m_viewport = gui.create("WIViewport",self.m_aspectRatioWrapper)

	local function create_text_element(font,pos,color)
		local textColor = Color(182,182,182)
		local el = gui.create("WIText",self)
		el:SetFont(font)
		el:SetColor(textColor)
		el:SetPos(pos)
		return el
	end
	local textColor = Color(182,182,182)
	self.m_timeGlobal = create_text_element("pfm_large",Vector2(20,15),textColor)
	self.m_timeGlobal:SetText(util.get_pretty_time(0.0))
	self.m_timeGlobal:SizeToContents()

	self.m_timeLocal = create_text_element("pfm_large",Vector2(0,15),textColor)
	self.m_timeLocal:SetText(util.get_pretty_time(0.0))
	self.m_timeLocal:SizeToContents()

	textColor = Color(152,152,152)
	self.m_filmClipParent = create_text_element("pfm_medium",Vector2(0,3),textColor)

	self.m_filmClip = create_text_element("pfm_medium",Vector2(0,16),textColor)

	self:InitializePlayControls()
	self:InitializeManipulatorControls()
	self:InitializeCameraControls()

	self.m_viewport:SetType(gui.WIViewport.VIEWPORT_TYPE_3D)

	-- This controls the behavior that allows controlling the camera while holding the right mouse button down
	self.m_viewport:SetMouseInputEnabled(true)
	self.m_cbClickMouseInput = self.m_viewport:AddCallback("OnMouseEvent",function(el,mouseButton,state,mods)
		if(mouseButton ~= input.MOUSE_BUTTON_LEFT and mouseButton ~= input.MOUSE_BUTTON_RIGHT) then return util.EVENT_REPLY_UNHANDLED end
		if(state ~= input.STATE_PRESS and state ~= input.STATE_RELEASE) then return util.EVENT_REPLY_UNHANDLED end

		local filmmaker = tool.get_filmmaker()
		if(self.m_inCameraControlMode and mouseButton == input.MOUSE_BUTTON_RIGHT and state == input.STATE_RELEASE and filmmaker:IsValid() and filmmaker:HasFocus() == false) then
			self:SetCameraMode(gui.PFMViewport.CAMERA_MODE_PLAYBACK)
			filmmaker:TrapFocus(true)
			filmmaker:RequestFocus()
			input.set_cursor_pos(self.m_oldCursorPos)
			self.m_inCameraControlMode = false
			return util.EVENT_REPLY_HANDLED
		end

		local el = gui.get_element_under_cursor()
		if(util.is_valid(el) and (el == self or el:IsDescendantOf(self))) then
			local action
			if(mouseButton == input.MOUSE_BUTTON_LEFT) then action = input.ACTION_ATTACK
			else action = input.ACTION_ATTACK2 end

			local filmmaker = tool.get_filmmaker()
			if(mouseButton == input.MOUSE_BUTTON_RIGHT and state == input.STATE_PRESS) then
				self.m_oldCursorPos = input.get_cursor_pos()
				self:SetCameraMode(gui.PFMViewport.CAMERA_MODE_WALK)
				input.center_cursor()
				filmmaker:TrapFocus(false)
				filmmaker:KillFocus()
				self.m_inCameraControlMode = true
			end
			return util.EVENT_REPLY_HANDLED
		end
		return util.EVENT_REPLY_UNHANDLED
	end)
	self:SetCameraMode(gui.PFMViewport.CAMERA_MODE_PLAYBACK)

	self.m_vrControllers = {}
end
function gui.PFMViewport:OnRemove()
	for _,ent in ipairs(self.m_vrControllers) do
		if(ent:IsValid()) then ent:Remove() end
	end
end
function gui.PFMViewport:SetCameraMode(camMode)
	pfm.log("Changing camera mode to " .. ((camMode == gui.PFMViewport.CAMERA_MODE_PLAYBACK and "playback") or (camMode == gui.PFMViewport.CAMERA_MODE_FLY and "fly") or "walk"))
	self.m_cameraMode = camMode

	ents.PFMCamera.set_camera_enabled(camMode == gui.PFMViewport.CAMERA_MODE_PLAYBACK)

	-- We need to notify the server to change the player's movement mode (i.e. noclip/walk)
	local packet = net.Packet()
	packet:WriteUInt8(camMode)
	local cam = game.get_render_scene_camera()
	if(cam ~= nil) then
		packet:WriteBool(true)
		packet:WriteVector(cam:GetEntity():GetPos())
		packet:WriteQuaternion(cam:GetEntity():GetRotation())
	else packet:WriteBool(false) end
	net.send(net.PROTOCOL_SLOW_RELIABLE,"sv_pfm_camera_mode",packet)
end
function gui.PFMViewport:SetGlobalTime(time)
	if(util.is_valid(self.m_timeGlobal)) then
		self.m_timeGlobal:SetText(util.get_pretty_time(time))
		self.m_timeGlobal:SizeToContents()
	end
end
function gui.PFMViewport:SetLocalTime(time)
	if(util.is_valid(self.m_timeLocal)) then
		self.m_timeLocal:SetText(util.get_pretty_time(time))
		self.m_timeLocal:SizeToContents()
	end
end
function gui.PFMViewport:SetFilmClipName(name)
	if(util.is_valid(self.m_filmClip)) then
		self.m_filmClip:SetText(name)
		self.m_filmClip:SizeToContents()

		self:UpdateFilmLabelPositions()
	end
end
function gui.PFMViewport:SetFilmClipParentName(name)
	if(util.is_valid(self.m_filmClipParent)) then
		self.m_filmClipParent:SetText(name)
		self.m_filmClipParent:SizeToContents()

		self:UpdateFilmLabelPositions()
	end
end
function gui.PFMViewport:UpdateFilmLabelPositions()
	if(util.is_valid(self.m_filmClipParent)) then
		self.m_filmClipParent:SetX(self:GetWidth() *0.5 -self.m_filmClipParent:GetWidth() *0.5)
	end
	if(util.is_valid(self.m_filmClip)) then
		self.m_filmClip:SetX(self:GetWidth() *0.5 -self.m_filmClip:GetWidth() *0.5)
	end
end
function gui.PFMViewport:InitializePlayControls()
	local controls = gui.create("WIHBox",self,0,self.m_vpBg:GetBottom() +4)
	self.m_btFirstFrame = gui.PFMButton.create(controls,"gui/pfm/icon_cp_firstframe","gui/pfm/icon_cp_firstframe_activated",function()
		print("PRESS")
	end)
	self.m_btPrevClip = gui.PFMButton.create(controls,"gui/pfm/icon_cp_prevclip","gui/pfm/icon_cp_prevclip_activated",function()
		print("PRESS")
	end)
	self.m_btPrevFrame = gui.PFMButton.create(controls,"gui/pfm/icon_cp_prevframe","gui/pfm/icon_cp_prevframe_activated",function()
		print("PRESS")
	end)
	self.m_btRecord = gui.PFMButton.create(controls,"gui/pfm/icon_cp_record","gui/pfm/icon_cp_record_activated",function()
		print("PRESS")
	end)
	self.m_btPlay = gui.create("WIPFMPlayButton",controls)
	self.m_btNextFrame = gui.PFMButton.create(controls,"gui/pfm/icon_cp_nextframe","gui/pfm/icon_cp_nextframe_activated",function()
		print("PRESS")
	end)
	self.m_btNextClip = gui.PFMButton.create(controls,"gui/pfm/icon_cp_nextclip","gui/pfm/icon_cp_nextclip_activated",function()
		print("PRESS")
	end)
	self.m_btLastFrame = gui.PFMButton.create(controls,"gui/pfm/icon_cp_lastframe","gui/pfm/icon_cp_lastframe_activated",function()
		print("PRESS")
	end)
	controls:SetHeight(self.m_btFirstFrame:GetHeight())
	controls:Update()
	controls:SetX(self:GetWidth() *0.5 -controls:GetWidth() *0.5)
	controls:SetAnchor(0.5,1,0.5,1)
	self.m_playControls = controls
end
function gui.PFMViewport:InitializeManipulatorControls()
	local controls = gui.create("WIHBox",self,0,self.m_vpBg:GetBottom() +4)
	self.m_btSelect = gui.PFMButton.create(controls,"gui/pfm/icon_manipulator_select","gui/pfm/icon_manipulator_select_activated",function()
		print("PRESS")
	end)
	self.m_btMove = gui.PFMButton.create(controls,"gui/pfm/icon_manipulator_move","gui/pfm/icon_manipulator_move_activated",function()
		print("PRESS")
	end)
	self.m_btRotate = gui.PFMButton.create(controls,"gui/pfm/icon_manipulator_rotate","gui/pfm/icon_manipulator_rotate_activated",function()
		print("PRESS")
	end)
	self.m_btScreen = gui.PFMButton.create(controls,"gui/pfm/icon_manipulator_screen","gui/pfm/icon_manipulator_screen_activated",function()
		print("PRESS")
	end)
	controls:SetHeight(self.m_btSelect:GetHeight())
	controls:Update()
	controls:SetX(3)
	controls:SetAnchor(0,1,0,1)
	self.manipulatorControls = controls
end
function gui.PFMViewport:InitializeCameraControls()
	local controls = gui.create("WIHBox",self,0,self.m_vpBg:GetBottom() +4)

	self.m_btVr = gui.PFMButton.create(controls,"gui/pfm/icon_cp_generic","gui/pfm/icon_cp_generic",function()
		ents.PFMCamera.set_vr_view_enabled(not ents.PFMCamera.is_vr_view_enabled())
		if(ents.PFMCamera.is_vr_view_enabled()) then
			for i=0,openvr.MAX_TRACKED_DEVICE_COUNT -1 do
				if(openvr.get_tracked_device_class(i) == openvr.TRACKED_DEVICE_CLASS_CONTROLLER) then
					local ent = ents.create("pfm_vr_controller")
					ent:Spawn()

					table.insert(self.m_vrControllers,ent)

					local vrC = ent:GetComponent(ents.COMPONENT_VR_CONTROLLER)
					if(vrC ~= nil) then vrC:SetControllerId(i) end

					local pfmVrC = ent:GetComponent(ents.COMPONENT_PFM_VR_CONTROLLER)
					if(pfmVrC ~= nil) then
						-- TODO: This is just a prototype implementation, do this properly!
						local el = pfmVrC:GetGUIElement():GetPlayButton()
						if(util.is_valid(el)) then
							el:AddCallback("OnStateChanged",function(el,oldState,state)
								local btPlay = self:GetPlayButton()
								if(util.is_valid(btPlay) == false) then return end
								if(state == gui.PFMPlayButton.STATE_PLAYING) then
									btPlay:Pause()
								elseif(state == gui.PFMPlayButton.STATE_PAUSED) then
									btPlay:Play()
								end
							end)
						end
					end
				end
			end
		else
			for _,ent in ipairs(self.m_vrControllers) do
				if(ent:IsValid()) then ent:Remove() end
			end
			self.m_vrControllers = {}
		end
	end)
	local pText = gui.create("WIText",self.m_btVr)
	pText:SetText("VR")
	pText:SizeToContents()
	pText:SetPos(self.m_btVr:GetWidth() *0.5 -pText:GetWidth() *0.5,self.m_btVr:GetHeight() *0.5 -pText:GetHeight() *0.5)
	pText:SetAnchor(0.5,0.5,0.5,0.5)
	pText:SetColor(Color.White)

	self.m_toneMapping = gui.create("WIDropDownMenu",controls)
	self.m_toneMapping:SetText("Tonemapping")
	local toneMappingOptions = {
		"Gamma Correction",
		"Reinhard",
		"Hejil-Richard",
		"Uncharted",
		"Aces",
		"Gran Turismo"
	}
	for _,option in ipairs(toneMappingOptions) do
		self.m_toneMapping:AddOption(option)
	end
	self.m_toneMapping:AddCallback("OnOptionSelected",function(el,idx)
		console.run("cl_render_tone_mapping " .. tostring(idx))
	end)
	self.m_toneMapping:SetSize(128,25)

	self.m_btAutoAim = gui.PFMButton.create(controls,"gui/pfm/icon_viewport_autoaim","gui/pfm/icon_viewport_autoaim_activated",function()
		print("PRESS")
	end)
	self.m_btCamera = gui.PFMButton.create(controls,"gui/pfm/icon_cp_camera","gui/pfm/icon_cp_camera_activated",function()
		print("PRESS")
	end)
	self.m_btGear = gui.PFMButton.create(controls,"gui/pfm/icon_gear","gui/pfm/icon_gear_activated",function()
		print("PRESS")
	end)
	controls:SetHeight(self.m_btAutoAim:GetHeight())
	controls:Update()
	controls:SetX(self:GetWidth() -controls:GetWidth() -3)
	controls:SetAnchor(1,1,1,1)
	self.manipulatorControls = controls
end
function gui.PFMViewport:GetPlayButton() return self.m_btPlay end
function gui.PFMViewport:GetViewport() return self.m_viewport end
function gui.PFMViewport:OnSizeChanged(w,h)
	self:Update()
end
function gui.PFMViewport:OnUpdate()
	if(util.is_valid(self.m_timeLocal)) then
		self.m_timeLocal:SetX(self:GetWidth() -self.m_timeLocal:GetWidth() -20)
	end
	self:UpdateFilmLabelPositions()
end
gui.register("WIPFMViewport",gui.PFMViewport)
