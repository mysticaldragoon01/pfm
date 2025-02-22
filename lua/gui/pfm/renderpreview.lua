--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("/gui/aspectratio.lua")
include("/gui/hbox.lua")
include("/gui/resizer.lua")
include("/gui/pfm/slider.lua")
include("/gui/pfm/button.lua")
include("/gui/pfm/controls_menu.lua")
include("/gui/pfm/base_viewport.lua")
include("/gui/editableentry.lua")
include("/gui/wifiledialog.lua")
include("/gui/toggleoption.lua")
include("/gui/pfm/raytracedanimationviewport.lua")

util.register_class("gui.PFMRenderPreview",gui.PFMBaseViewport)

gui.PFMRenderPreview.IMAGE_TYPE_FLAT = 0
gui.PFMRenderPreview.IMAGE_TYPE_MONO = 1
gui.PFMRenderPreview.IMAGE_TYPE_STEREO = 2

function gui.PFMRenderPreview:__init()
	gui.PFMBaseViewport.__init(self)
end
function gui.PFMRenderPreview:OnInitialize()
	gui.PFMBaseViewport.OnInitialize(self)

	self.m_cbOnTimeOffsetChanged = tool.get_filmmaker():AddCallback("OnTimeOffsetChanged",function(fm,offset)
		local imgFilePath = self:GetCurrentFrameFilePath()
		if(imgFilePath == nil) then return end
		self.m_rt:LoadPreviewImage("render/" .. imgFilePath)
		--self:UpdateDepthOfField()
		-- self.m_test = true
		self:EnableThinking()
	end)
end
function gui.PFMRenderPreview:InitializeViewport(parent)
	gui.PFMBaseViewport.InitializeViewport(self,parent)
	self.m_rt = gui.create("WIPFMRaytracedAnimationViewport",parent)
	self.m_rt:SetProjectManager(tool.get_filmmaker())
	self.m_rt:GetToneMappedImageElement():SetVRCamera(game.get_primary_camera())
	self.m_rt:AddCallback("OnProgressChanged",function(rt,progress)
		self:CallCallbacks("OnProgressChanged",progress)
	end)
	self.m_rt:AddCallback("OnFrameComplete",function(rt,state,job)
		local rtJob = self.m_rt:GetRTJob()
		local tRender = rtJob:GetRenderTime()
		print("Frame complete! Rendering took " .. tRender .. " seconds!")

		-- Save the image if it's not a preview render
		local renderSettings = self.m_rt:GetRenderSettings()
		if(renderSettings:IsRenderPreview() == false) then
			local outputPath = self:GetOutputPath()

			file.create_path(util.Path(outputPath):GetPath())
			print("Saving image as " .. outputPath .. "...")
			local framePath = self:GetFrameFilePath(rtJob:GetRenderResultFrameIndex())
			self.m_rt:ClearCachedPreview()
			self.m_rt:SaveImage(outputPath,self.m_rt:GetImageSaveFormat())
			-- TODO
			-- self.m_rt:GeneratePreviewImage("render/" .. framePath,self.m_rt:GetRenderResultRenderSettings())
		end
	end)
	self.m_rt:AddCallback("OnSceneComplete",function(rt,scene)
		local outputPath = self:GetOutputPath()
		if(outputPath == nil) then return end
		outputPath = util.Path(outputPath)
		file.create_path(outputPath:GetPath())
		local f = file.open(outputPath:GetString() .. ".prt",bit.bor(file.OPEN_MODE_WRITE,file.OPEN_MODE_BINARY))
		if(f == nil) then return end
		local ds = util.DataStream()
		local serializationData = unirender.Scene.SerializationData()
		serializationData.outputFileName = outputPath:GetString()
		scene:Save(ds,outputPath:GetPath(),serializationData)
		ds:Seek(0)
		f:Write(ds)
		f:Close()

		self.m_sceneFiles = self.m_sceneFiles or {}
		table.insert(self.m_sceneFiles,outputPath:GetString() .. ".prt")
	end)
	self.m_rt:AddCallback("OnComplete",function(rt,state)
		local renderSettings = self.m_rt:GetRenderSettings()
		if(renderSettings:IsRenderPreview() == false and renderSettings:IsPreStageOnly() and self.m_sceneFiles ~= nil) then
			local outputPath = self:GetOutputPath()
			if(outputPath ~= nil) then
				outputPath = util.Path(outputPath)
				pfm.RaytracingRenderJob.generate_job_batch_script(self.m_sceneFiles)
			end
		end
		self.m_sceneFiles = nil

		self.m_renderBtContainer:SetVisible(true)
		self.m_btCancel:SetVisible(false)
		self.m_btStop:SetVisible(false)
		console.run("cl_max_fps","-1") -- Unclamp FPS

		self.m_rt:GetToneMappedImageElement():SetStereo(self.m_renderedImageType == gui.PFMRenderPreview.IMAGE_TYPE_STEREO)
	end)
end
function gui.PFMRenderPreview:InitializeToneMapControls(p,settings)
	local toneMapping = p:AddDropDownMenu("tonemapping","tonemapping",{
		-- {"-1",toneMapping:AddOption(locale.get_text("pfm_cycles_tone_mapping_none_hdr")},
		{tostring(shader.TONE_MAPPING_NONE),locale.get_text("none")},
		{tostring(shader.TONE_MAPPING_GAMMA_CORRECTION),locale.get_text("gamma_correction")},
		{tostring(shader.TONE_MAPPING_REINHARD),"Reinhard"},
		{tostring(shader.TONE_MAPPING_HEJIL_RICHARD),"Hejil-Richard"},
		{tostring(shader.TONE_MAPPING_UNCHARTED),"Uncharted"},
		{tostring(shader.TONE_MAPPING_ACES),"Aces"},
		{tostring(shader.TONE_MAPPING_GRAN_TURISMO),"Gran Turismo"},

		{tostring(shader.PFMTonemapping.TONE_MAPPING_WARD),"Ward"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_FERWERDA),"Ferwerda"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_SCHLICK),"Schlick"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_TUMBLIN_RUSHMEIER),"Tumblin-Rushmeier"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_DRAGO),"Drago"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_REINHARD_DEVLIN),"Reinhard-Devlin"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_FILMLIC1),"Filmic 1"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_FILMLIC2),"Filmic 2"},
		{tostring(shader.PFMTonemapping.TONE_MAPPING_INSOMNIAC),"Insomniac"}
	},0)
	toneMapping:SetVisible(false)
	toneMapping:SetTooltip(locale.get_text("pfm_cycles_tone_mapping_desc"))
	toneMapping:AddCallback("OnOptionSelected",function(el,option)
		self.m_ctrlExposure:SetVisible(false)
		self.m_ctrlLdMax:SetVisible(false)
		self.m_ctrlCMax:SetVisible(false)
		self.m_ctrlCurveParam:SetVisible(false)
		self.m_ctrlGammaSlope:SetVisible(false)
		self.m_ctrlGammaStart:SetVisible(false)
		self.m_ctrlBias:SetVisible(false)
		self.m_ctrlCompressionCurveParam:SetVisible(false)
		self.m_ctrlIntensityAdjustmentParam:SetVisible(false)
		self.m_ctrlChromaticAdapation:SetVisible(false)
		self.m_ctrlLightAdaptation:SetVisible(false)
		self.m_ctrlCutoff:SetVisible(false)
		self.m_ctrlWhitePoint:SetVisible(false)
		self.m_ctrlBlackPoint:SetVisible(false)
		self.m_ctrlToeStrength:SetVisible(false)
		self.m_ctrlShoulderStrength:SetVisible(false)
		self.m_ctrlCrossOverPoint:SetVisible(false)

		option = tonumber(toneMapping:GetOptionValue(option))
		self:ApplyToneMappingSettings(option)
		-- self.m_rt:SetToneMapping(option)
		if(option == -1) then return end

		self.m_ctrlExposure:SetVisible(true)
		if(option == shader.PFMTonemapping.TONE_MAPPING_WARD) then
			self.m_ctrlLdMax:SetVisible(true)

			self.m_ctrlLdMax:SetRange(0,200)
			self.m_ctrlLdMax:SetDefault(100)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_FERWERDA) then
			self.m_ctrlLdMax:SetVisible(true)

			self.m_ctrlLdMax:SetRange(0,160)
			self.m_ctrlLdMax:SetDefault(80)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_SCHLICK) then
			self.m_ctrlCurveParam:SetVisible(true)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_TUMBLIN_RUSHMEIER) then
			self.m_ctrlLdMax:SetVisible(true)
			self.m_ctrlCMax:SetVisible(true)

			self.m_ctrlLdMax:SetRange(1,200)
			self.m_ctrlLdMax:SetDefault(86)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_DRAGO) then
			self.m_ctrlLdMax:SetVisible(true)

			self.m_ctrlLdMax:SetRange(0,200)
			self.m_ctrlLdMax:SetDefault(100)

			self.m_ctrlGammaSlope:SetVisible(true)
			self.m_ctrlGammaStart:SetVisible(true)
			self.m_ctrlBias:SetVisible(true)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_REINHARD_DEVLIN) then
			self.m_ctrlCompressionCurveParam:SetVisible(true)
			self.m_ctrlIntensityAdjustmentParam:SetVisible(true)
			self.m_ctrlChromaticAdapation:SetVisible(true)
			self.m_ctrlLightAdaptation:SetVisible(true)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_FILMLIC1) then
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_FILMLIC2) then
			self.m_ctrlCutoff:SetVisible(true)
		elseif(option == shader.PFMTonemapping.TONE_MAPPING_INSOMNIAC) then
			self.m_ctrlWhitePoint:SetVisible(true)
			self.m_ctrlBlackPoint:SetVisible(true)
			self.m_ctrlToeStrength:SetVisible(true)
			self.m_ctrlShoulderStrength:SetVisible(true)
			self.m_ctrlCrossOverPoint:SetVisible(true)
		end
	end)
	if(tool.get_filmmaker():IsDeveloperModeEnabled() == false) then p:SetControlVisible("tonemapping",false) end -- Tonemapping currently disabled, since Cycles now handles tonemapping internally. This may be re-enabled in the future to allow a wider variety of tonemapping algorithms to be used.
	self.m_ctrlToneMapping = toneMapping

	-- Exposure factor
	local fApplyToneMappingSettings = function() self:ApplyToneMappingSettings(self.m_rt:GetToneMapping()) end
	self.m_ctrlExposure = p:AddSliderControl(locale.get_text("pfm_exposure"),"exposure",settings:GetExposure(),0,100,fApplyToneMappingSettings)
	p:LinkToUDMProperty("exposure",settings,"exposure")

	-- Max luminance capability of the display
	self.m_ctrlLdMax = p:AddSliderControl(locale.get_text("pfm_tone_mapping_ldmax"),nil,100,0,200,fApplyToneMappingSettings)

	-- Maximum contrast ratio between on-screen luminances
	self.m_ctrlCMax = p:AddSliderControl(locale.get_text("pfm_tone_mapping_cmax"),nil,50,1,500,fApplyToneMappingSettings)

	-- Rational mapping curve parameter
	self.m_ctrlCurveParam = p:AddSliderControl(locale.get_text("pfm_tone_mapping_curve_param"),nil,200,1,1000,fApplyToneMappingSettings)

	-- Gamma slope
	self.m_ctrlGammaSlope = p:AddSliderControl(locale.get_text("pfm_tone_mapping_gamma_slope"),nil,4.5,0,10,fApplyToneMappingSettings)

	-- Gamma start
	self.m_ctrlGammaStart = p:AddSliderControl(locale.get_text("pfm_tone_mapping_gamma_start"),nil,0.018,0,2,fApplyToneMappingSettings)

	-- Bias
	self.m_ctrlBias = p:AddSliderControl(locale.get_text("pfm_tone_mapping_bias"),nil,0.85,0,1,fApplyToneMappingSettings)

	-- Compression curve adjustment parameter
	self.m_ctrlCompressionCurveParam = p:AddSliderControl(locale.get_text("pfm_tone_mapping_compression_curve_adjustment_param"),nil,0.5,0,1,fApplyToneMappingSettings)

	-- Compression curve adjustment parameter
	self.m_ctrlIntensityAdjustmentParam = p:AddSliderControl(locale.get_text("pfm_tone_mapping_intensity_adjustment_param_desc"),nil,1,0,1000,fApplyToneMappingSettings)

	-- Chromatic adaptation
	self.m_ctrlChromaticAdapation = p:AddSliderControl(locale.get_text("pfm_tone_mapping_chromatic_adaptation"),nil,0,0,1,fApplyToneMappingSettings)

	-- Light adaptation
	self.m_ctrlLightAdaptation = p:AddSliderControl(locale.get_text("pfm_tone_mapping_light_adaptation"),nil,1,0,1,fApplyToneMappingSettings)

	-- Cutoff
	self.m_ctrlCutoff = p:AddSliderControl(locale.get_text("pfm_tone_mapping_cutoff"),nil,0.025,0,0.5,fApplyToneMappingSettings)

	-- White point
	self.m_ctrlWhitePoint = p:AddSliderControl(locale.get_text("pfm_tone_mapping_white_point"),nil,10,0,20,fApplyToneMappingSettings)

	-- Black point
	self.m_ctrlBlackPoint = p:AddSliderControl(locale.get_text("pfm_tone_mapping_black_point"),nil,0.1,0,2,fApplyToneMappingSettings)

	-- Toe strength
	self.m_ctrlToeStrength = p:AddSliderControl(locale.get_text("pfm_tone_mapping_toe_strength"),nil,0.7,0,1,fApplyToneMappingSettings)

	-- Shoulder strength
	self.m_ctrlShoulderStrength = p:AddSliderControl(locale.get_text("pfm_tone_mapping_shoulder_strength"),nil,0.8,0,1,fApplyToneMappingSettings)

	-- Cross-over point
	self.m_ctrlCrossOverPoint = p:AddSliderControl(locale.get_text("pfm_tone_mapping_cross_over_point"),nil,2,0,10,fApplyToneMappingSettings)

	toneMapping:SelectOption(4)
end
function gui.PFMRenderPreview:ApplyToneMappingSettings(toneMapping)
	-- self.m_rt:SetExposure(self.m_ctrlExposure:GetValue())

	local args = {}
	if(toneMapping == shader.PFMTonemapping.TONE_MAPPING_WARD) then
		table.insert(args,self.m_ctrlLdMax:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_FERWERDA) then
		table.insert(args,self.m_ctrlLdMax:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_SCHLICK) then
		table.insert(args,self.m_ctrlCurveParam:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_TUMBLIN_RUSHMEIER) then
		table.insert(args,self.m_ctrlLdMax:GetValue())
		table.insert(args,self.m_ctrlCMax:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_DRAGO) then
		table.insert(args,self.m_ctrlLdMax:GetValue())
		table.insert(args,self.m_ctrlBias:GetValue())
		table.insert(args,self.m_ctrlGammaStart:GetValue())
		table.insert(args,self.m_ctrlGammaSlope:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_REINHARD_DEVLIN) then
		table.insert(args,self.m_ctrlChromaticAdapation:GetValue())
		table.insert(args,self.m_ctrlLightAdaptation:GetValue())
		table.insert(args,self.m_ctrlIntensityAdjustmentParam:GetValue())
		table.insert(args,self.m_ctrlCompressionCurveParam:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_FILMLIC1) then
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_FILMLIC2) then
		table.insert(args,self.m_ctrlCutoff:GetValue())
	elseif(toneMapping == shader.PFMTonemapping.TONE_MAPPING_INSOMNIAC) then
		table.insert(args,self.m_ctrlCrossOverPoint:GetValue())
		table.insert(args,self.m_ctrlBlackPoint:GetValue())
		table.insert(args,self.m_ctrlShoulderStrength:GetValue())
		table.insert(args,self.m_ctrlWhitePoint:GetValue())
		table.insert(args,self.m_ctrlToeStrength:GetValue())
	end
	self.m_rt:SetToneMappingArguments(args)
end
function gui.PFMRenderPreview:UpdateViewport(settings)
	self.m_rt:GetToneMappedImageElement():SetHorizontalRange(settings:GetPanoramaHorizontalRange())
	self.m_rt:GetToneMappedImageElement():SetStereo(false)
	self.m_rt:GetToneMappedImageElement():SetToneMappingAlgorithm(settings:GetHDROutput() and shader.TONE_MAPPING_GAMMA_CORRECTION or shader.TONE_MAPPING_NONE)
	self.m_rt:GetToneMappedImageElement():SetExposure(1.0) -- Exposure was already applied
	self.m_rt:SetSaveAsHDR(settings:GetHDROutput())
	self:UpdateVRMode()
end
function gui.PFMRenderPreview:UpdateVRMode()
	local enableVrView = (self.m_renderedImageType ~= gui.PFMRenderPreview.IMAGE_TYPE_FLAT and tonumber(self.m_ctrlPreviewMode:GetOptionValue(self.m_ctrlPreviewMode:GetSelectedOption())) ~= fudm.PFMRenderSettings.VIEWPORT_MODE_FLAT)
	self.m_rt:GetToneMappedImageElement():SetVRView(enableVrView,tool.get_filmmaker())
end
function gui.PFMRenderPreview:GetOutputPath()
	local rtJob = self.m_rt:GetRTJob()

	local renderSettings = self.m_rt:GetRenderSettings()
	if(renderSettings:IsRenderPreview() == true) then return end
	local framePath = self:GetFrameFilePath(rtJob:GetRenderResultFrameIndex())
	local outputPath = "render/" .. framePath
	local remainingSubStages = rtJob:GetRenderResultRemainingSubStages()
	if(remainingSubStages > 0) then outputPath = outputPath .. "_" .. remainingSubStages end
	return outputPath
end
function gui.PFMRenderPreview:OnRemove()
	self:CancelRendering()
	if(util.is_valid(self.m_cbOnTimeOffsetChanged)) then self.m_cbOnTimeOffsetChanged:Remove() end
end
function gui.PFMRenderPreview:InitializeSettings(parent)
	gui.PFMBaseViewport.InitializeSettings(self,parent)
	local p = self.m_settingsBox

	-- Preset
	local settings = tool.get_filmmaker():GetSettings()
	settings = (settings ~= nil) and settings:GetRenderSettings() or fudm.PFMRenderSettings()
	self.m_ctrlPreset = p:AddDropDownMenu(locale.get_text("preset"),"preset",{
		{"standard",locale.get_text("pfm_rt_preset_standard")},
		-- {"cinematic",locale.get_text("pfm_rt_preset_cinematic")},
		{"vr",locale.get_text("pfm_rt_preset_vr")}
	},settings:GetPreset())

	-- Render Engine
	self.m_ctrlRenderEngine = p:AddDropDownMenu(locale.get_text("pfm_render_engine"),"render_engine",{
		{"cycles",locale.get_text("pfm_render_engine_cycles")},
		{"luxcorerender",locale.get_text("pfm_render_engine_luxcorerender")}
	},"cycles")
	p:LinkToUDMProperty("render_engine",settings,"renderEngine")
	
	-- Render Mode
	self.m_ctrlRenderMode = p:AddDropDownMenu(locale.get_text("pfm_render_mode"),"render_mode",{
		{tostring(fudm.PFMRenderSettings.MODE_COMBINED),locale.get_text("pfm_cycles_bake_type_combined")},
		{tostring(fudm.PFMRenderSettings.MODE_ALBEDO),locale.get_text("pfm_cycles_bake_type_albedo")},
		{tostring(fudm.PFMRenderSettings.MODE_NORMALS),locale.get_text("pfm_cycles_bake_type_normals")},
		{tostring(fudm.PFMRenderSettings.MODE_DEPTH),locale.get_text("pfm_cycles_bake_type_depth")},
		{tostring(fudm.PFMRenderSettings.MODE_ALPHA),"Alpha"},
		{tostring(fudm.PFMRenderSettings.MODE_GEOMETRY_NORMAL),"Geometry Normal"},
		{tostring(fudm.PFMRenderSettings.MODE_SHADING_NORMAL),"Shading Normal"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE),"Direct Diffuse"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE_REFLECT),"Direct Diffuse Reflect"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE_TRANSMIT),"Direct Diffuse Transmit"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY),"Direct Glossy"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY_REFLECT),"Direct Glossy Reflect"},
		{tostring(fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY_TRANSMIT),"Direct Glossy Transmit"},
		{tostring(fudm.PFMRenderSettings.MODE_EMISSION),"Emission"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE),"Indirect Diffuse"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE_REFLECT),"Indirect Diffuse Reflect"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE_TRANSMIT),"Indirect Diffuse Transmit"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY),"Indirect Glossy"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY_REFLECT),"Indirect Glossy Reflect"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY_TRANSMIT),"Indirect Glossy Transmit"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR),"Indirect Specular"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR_REFLECT),"Indirect Specular Reflect"},
		{tostring(fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR_TRANSMIT),"Indirect Specular Transmit"},
		{tostring(fudm.PFMRenderSettings.MODE_UV),"UV"},
		{tostring(fudm.PFMRenderSettings.MODE_IRRADIANCE),"Irradiance"},
		{tostring(fudm.PFMRenderSettings.MODE_NOISE),"Noise"},
		{tostring(fudm.PFMRenderSettings.MODE_CAUSTIC),"Caustic"}
	},tostring(settings:GetMode()))
	p:LinkToUDMProperty("render_mode",settings,"mode")
	if(tool.get_filmmaker():IsDeveloperModeEnabled() == false) then p:SetControlVisible("render_mode",false) end

	-- Device Type
	self.m_ctrlDeviceType = p:AddDropDownMenu(locale.get_text("pfm_cycles_device_type"),"device_type",{
		{tostring(fudm.PFMRenderSettings.DEVICE_TYPE_GPU),locale.get_text("pfm_cycles_device_type_gpu")},
		{tostring(fudm.PFMRenderSettings.DEVICE_TYPE_CPU),locale.get_text("pfm_cycles_device_type_cpu")}
	},tostring(settings:GetDeviceType()))
	p:LinkToUDMProperty("device_type",settings,"deviceType")

	-- Camera type
	self.m_ctrlCamType = p:AddDropDownMenu(locale.get_text("pfm_cycles_cam_type"),"cam_type",{
		{tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_PERSPECTIVE),locale.get_text("pfm_cycles_cam_type_perspective")},
		{tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_ORTHOGRAPHIC),locale.get_text("pfm_cycles_cam_type_orthographic")},
		{tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA),locale.get_text("pfm_cycles_cam_type_panorama")}
	},tostring(settings:GetCameraType()),function(camType,idx)
		p:SetControlVisible("panorama_type",idx == pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA)
		p:SetControlVisible("panorama_range",idx == pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA)
		p:SetControlVisible("equirect_mode",idx == pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA)
		self:UpdateVROptions()
	end)
	p:LinkToUDMProperty("cam_type",settings,"cameraType")

	self.m_ctrlPanoramaType = p:AddDropDownMenu(locale.get_text("pfm_cycles_cam_panorama"),"panorama_type",{
		{tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_EQUIRECTANGULAR),locale.get_text("pfm_cycles_cam_panorama_type_equirectangular")},
		{tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_FISHEYE_EQUIDISTANT),locale.get_text("pfm_cycles_cam_panorama_type_equidistant")},
		{tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_FISHEYE_EQUISOLID),locale.get_text("pfm_cycles_cam_panorama_type_equisolid")},
		{tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_MIRRORBALL),locale.get_text("pfm_cycles_cam_panorama_type_mirrorball")},
		{tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_CUBEMAP),locale.get_text("pfm_cycles_cam_panorama_type_cubemap")}
	},tostring(settings:GetPanoramaType()),function() self:UpdateVROptions() end)
	p:LinkToUDMProperty("panorama_type",settings,"panoramaType")
	p:SetControlVisible("panorama_type",false)

	self.m_ctrlEquirectMode = p:AddDropDownMenu(locale.get_text("pfm_cycles_cam_equirect_mode"),"equirect_mode",{
		{"mono",locale.get_text("mono")},
		{"stereo",locale.get_text("stereo")}
	},settings:IsStereoscopic() and 1 or 0,function() self:UpdateVROptions() end)
	p:LinkToUDMProperty("equirect_mode",settings,"stereoscopic",function(value) return value == "stereo" end,function(value) return value and "stereo" or "mono" end)
	p:SetControlVisible("equirect_mode",false)

	self.m_ctrlPreviewMode = p:AddDropDownMenu(locale.get_text("pfm_cycles_preview_mode"),"preview_mode",{
		{tostring(fudm.PFMRenderSettings.VIEWPORT_MODE_FLAT),locale.get_text("pfm_cycles_preview_mode_flat")},
		{tostring(fudm.PFMRenderSettings.VIEWPORT_MODE_360_LEFT_EYE),locale.get_text("pfm_cycles_preview_mode_360_left")},
		{tostring(fudm.PFMRenderSettings.VIEWPORT_MODE_360_RIGHT_EYE),locale.get_text("pfm_cycles_preview_mode_360_right")}
	},tostring(settings:GetViewportMode()),function() self:UpdateViewportMode() end)
	p:LinkToUDMProperty("preview_mode",settings,"viewportMode")
	p:SetControlVisible("preview_mode",false)

	-- Horizontal panorama range
	self.m_ctrlPanoramaRange = p:AddDropDownMenu(locale.get_text("pfm_cycles_cam_panorama_range"),"panorama_range",{
		{tostring(360),locale.get_text("pfm_cycles_degrees",{360})},
		{tostring(180),locale.get_text("pfm_cycles_degrees",{180})}
	},tostring(settings:GetPanoramaRange()))
	p:LinkToUDMProperty("panorama_range",settings,"panoramaRange")
	p:SetControlVisible("panorama_range",false)

	-- Quality preset
	local presets = {
		{
			name = "very_low",
			emission_strength = 0.0,
			samples = 20.0,
			max_transparency_bounces = 1
		},
		{
			name = "low",
			emission_strength = 0.0,
			samples = 40.0,
			max_transparency_bounces = 4
		},
		{
			name = "medium",
			emission_strength = 0.0,
			samples = 80.0,
			max_transparency_bounces = 8
		},
		{
			name = "high",
			emission_strength = 1.0,
			samples = 120.0,
			max_transparency_bounces = 64
		},
		{
			name = "very_high",
			emission_strength = 1.0,
			samples = 200.0,
			max_transparency_bounces = 128
		}
	}
	local options = {}
	for _,preset in ipairs(presets) do
		table.insert(options,{preset.name,locale.get_text("pfm_cycles_quality_preset_" .. preset.name)})
	end

	local qualityPreset = p:AddDropDownMenu(locale.get_text("pfm_cycles_quality_preset"),"quality_preset",options,0)

	-- Sample count
	--function gui.PFMControlsMenu:AddSliderControl(name,identifier,default,min,max,onChange,stepSize,integer)
	self.m_ctrlSamplesPerPixel = p:AddSliderControl(locale.get_text("pfm_samples_per_pixel"),"samples_per_pixel",settings:GetSamples(),1,500,nil,1.0,true)
	p:LinkToUDMProperty("samples_per_pixel",settings,"samples")

	-- Resolution
	local skipResolutionAttrCallbacks = false
	local ctrlResolution,ctrlResolutionWrapper = p:AddDropDownMenu(locale.get_text("pfm_resolution"),"resolution",{
		{"1280x720",locale.get_text("pfm_resolution_hd_ready")},
		{"1920x1080",locale.get_text("pfm_resolution_full_hd")},
		{"2560x1440",locale.get_text("pfm_resolution_quad_hd")},
		{"2048x1080",locale.get_text("pfm_resolution_2k")},
		{"3840x2160",locale.get_text("pfm_resolution_4k")},
		{"7680x4320",locale.get_text("pfm_resolution_8k")}
	},0,function()
		local width,height = self:GetResolution()
		skipResolutionAttrCallbacks = true
		settings:SetWidth(width)
		settings:SetHeight(height)
		skipResolutionAttrCallbacks = false
	end)
	self.m_ctrlResolution = ctrlResolution
	local function update_resolution()
		if(skipResolutionAttrCallbacks) then return end
		self.m_ctrlResolution:ClearSelectedOption()
		local text = tostring(settings:GetWidth()) .. "x" .. tostring(settings:GetHeight())
		if(ctrlResolution:HasOption(text)) then ctrlResolution:SelectOption(text)
		else self.m_ctrlResolution:SetText(text) end
		ctrlResolutionWrapper:UpdateText()
	end
	settings:GetWidthAttr():AddChangeListener(update_resolution)
	settings:GetHeightAttr():AddChangeListener(update_resolution)

	local w = settings:GetWidth()
	local h = settings:GetHeight()
	self.m_ctrlResolution:SetEditable(true)
	self.m_ctrlResolution:SelectOption(1)
	-- TODO: Add VR resolution options

	-- Choose a default sky
	-- Sky override
	local skyOverride
	skyOverride = p:AddFileEntry(locale.get_text("pfm_sky_override"),"sky_override",settings:GetSky(),function(resultHandler)
		local pFileDialog = gui.create_file_open_dialog(function(el,fileName)
			if(fileName == nil) then return end
			resultHandler(el:GetFilePath(true))
		end)
		pFileDialog:SetRootPath("materials")
		local path = file.get_file_path(skyOverride:GetValue())
		if(#path == 0) then path = "skies" end
		pFileDialog:SetPath(path)
		pFileDialog:SetExtensions({"hdr","png"})
		pFileDialog:Update()
	end)
	p:LinkToUDMProperty("sky_override",settings,"sky")
	self.m_ctrlSkyOverride = skyOverride

	-- Sky strength
	self.m_ctrlSkyStrength = p:AddSliderControl(locale.get_text("pfm_sky_strength"),"sky_strength",settings:GetSkyStrength(),0,2)
	p:LinkToUDMProperty("sky_strength",settings,"skyStrength")

	-- Sky yaw
	self.m_ctrlSkyYaw = p:AddSliderControl(locale.get_text("pfm_sky_yaw_angle"),"sky_yaw",settings:GetSkyYawAngle(),0,360)
	p:LinkToUDMProperty("sky_yaw",settings,"skyYawAngle")

	-- Max transparency bounces
	self.m_ctrlMaxTransparencyBounces = p:AddSliderControl(locale.get_text("pfm_max_transparency_bounces"),"max_transparency_bounces",settings:GetMaxTransparencyBounces(),0,100)
	p:LinkToUDMProperty("max_transparency_bounces",settings,"maxTransparencyBounces")

	-- Light intensity factor
	self.m_ctrlLightIntensityFactor = p:AddSliderControl(locale.get_text("pfm_light_intensity_factor"),"light_intensity_factor",settings:GetLightIntensityFactor(),0,20)
	p:LinkToUDMProperty("light_intensity_factor",settings,"lightIntensityFactor")

	-- Emission strength
	self.m_ctrlEmissionStrength = p:AddSliderControl(locale.get_text("pfm_emission_strength"),"emission_strength",settings:GetEmissionStrength(),0,20,function()
		pfm.load_cycles()
		unirender.PBRShader.set_global_emission_strength(self.m_ctrlEmissionStrength:GetValue())
	end)
	p:LinkToUDMProperty("emission_strength",settings,"emissionStrength")

	-- Number of frames
	self.m_ctrlFrameCount = p:AddSliderControl(locale.get_text("pfm_number_of_frames_to_render"),"frame_count",settings:GetNumberOfFrames(),1,100,nil,1.0,true)
	p:LinkToUDMProperty("frame_count",settings,"numberOfFrames")
	self.m_ctrlFrameCount:AddCallback("PopulateContextMenu",function(p,pContext)
		pContext:AddItem(locale.get_text("pfm_number_of_frames_set_to_end_of_clip"),function()
			if(self:IsValid() == false) then return end
			local pfm = tool.get_filmmaker()
			local numFrames
			local startFrame,endFrame = pfm:GetPlayheadClipRange()
			startFrame = pfm:GetFrameOffset()
			if(startFrame ~= nil) then numFrames = math.max(endFrame -startFrame +1,1)
			else numFrames = 0 end
			self.m_ctrlFrameCount:GrowRangeToValue(numFrames)
			self.m_ctrlFrameCount:SetValue(numFrames)
		end)
		pContext:AddItem(locale.get_text("pfm_number_of_frames_set_to_end_of_session"),function()
			if(self:IsValid() == false) then return end
			local pfm = tool.get_filmmaker()
			local numFrames = math.max(pfm:GetLastFrameIndex() -pfm:GetFrameOffset() +1,1)
			self.m_ctrlFrameCount:GrowRangeToValue(numFrames)
			self.m_ctrlFrameCount:SetValue(numFrames)
		end)
	end)

	local _,colorTransforms = file.find("modules/open_color_io/configs/*")
	local colorTransformOptions = {{"none","none"}}
	for _,ct in ipairs(colorTransforms) do
		table.insert(colorTransformOptions,{ct,ct})
	end
	self.m_ctrlColorTransform = p:AddDropDownMenu(locale.get_text("pfm_color_transform"),"color_transform",colorTransformOptions,settings:GetColorTransform())
	p:LinkToUDMProperty("color_transform",settings,"colorTransform")

	-- TODO: Allow custom looks for custom color transforms!
	self.m_ctrlColorTransformLook = p:AddDropDownMenu(locale.get_text("pfm_color_transform_look"),"color_transform_look",{
		{"None",locale.get_text("none")},
		{"Very High Contrast",locale.get_text("pfm_color_transform_filmic_blender_very_high_contrast")},
		{"High Contrast",locale.get_text("pfm_color_transform_filmic_blender_high_contrast")},
		{"Medium High Contrast",locale.get_text("pfm_color_transform_filmic_blender_medium_high_contrast")},
		{"Medium Contrast",locale.get_text("pfm_color_transform_filmic_blender_medium_contrast")},
		{"Medium Low Contrast",locale.get_text("pfm_color_transform_filmic_blender_medium_low_contrast")},
		{"Low Contrast",locale.get_text("pfm_color_transform_filmic_blender_low_contrast")},
		{"Very Low Contrast",locale.get_text("pfm_color_transform_filmic_blender_very_low_contrast")}
	},settings:GetColorTransformLook())
	p:LinkToUDMProperty("color_transform_look",settings,"colorTransformLook")

	-- Output format
	local gammaCorrection = 2.2
	self.m_ctrlOutputFormat = p:AddDropDownMenu(locale.get_text("pfm_cycles_output_format"),"output_format",{
		{tostring(util.IMAGE_FORMAT_HDR),"HDR"},
		{tostring(util.IMAGE_FORMAT_PNG),"PNG (" .. locale.get_text("pfm_gamma_corrected",{gammaCorrection}) .. ")"},
		{tostring(util.IMAGE_FORMAT_BMP),"BMP (" .. locale.get_text("pfm_gamma_corrected",{gammaCorrection}) .. ")"},
		{tostring(util.IMAGE_FORMAT_TGA),"TGA (" .. locale.get_text("pfm_gamma_corrected",{gammaCorrection}) .. ")"},
		{tostring(util.IMAGE_FORMAT_JPG),"JPG (" .. locale.get_text("pfm_gamma_corrected",{gammaCorrection}) .. ")"}
	},tostring(settings:GetOutputFormat()),function(el,option)
		local format = tonumber(self.m_ctrlOutputFormat:GetOptionValue(self.m_ctrlOutputFormat:GetSelectedOption()))
		self.m_rt:SetImageSaveFormat(format)
	end)
	p:LinkToUDMProperty("output_format",settings,"outputFormat")

	-- Preview quality
	self.m_ctrlPreviewQuality = p:AddDropDownMenu(locale.get_text("pfm_cycles_preview_quality"),"preview_quality",{
		{tostring(fudm.PFMRenderSettings.PREVIEW_QUALITY_LOW),locale.get_text("low")},
		{tostring(fudm.PFMRenderSettings.PREVIEW_QUALITY_MEDIUM),locale.get_text("medium")},
		{tostring(fudm.PFMRenderSettings.PREVIEW_QUALITY_HIGH),locale.get_text("high")}
	},tostring(fudm.PFMRenderSettings.PREVIEW_QUALITY_LOW))
	p:LinkToUDMProperty("preview_quality",settings,"previewQuality")

	-- Output directory
	--[[local outputDir = gui.create("WIFileEntry",p)
	outputDir:SetBrowseHandler(function(resultHandler)
		local pFileDialog = gui.create_file_open_dialog(function(el,fileName)
			if(fileName == nil) then return end
			resultHandler(fileName)
		end)
		pFileDialog:MakeDirectoryExplorer()
		pFileDialog:SetRootPath(util.get_addon_path())
		pFileDialog:SetPath(outputDir:GetValue())
		pFileDialog:Update()
	end)
	outputDir:SetValue("render/")
	outputDir:SetTooltip(locale.get_text("pfm_output_directory_desc"))
	self.m_ctrlOutputDir = outputDir

	outputDir:Wrap("WIEditableEntry"):SetText(locale.get_text("pfm_output_directory"))]]

	self.m_ctrlDenoise = p:AddToggleControl(locale.get_text("pfm_denoise_image"),"denoise",settings:ShouldDenoise())
	-- self.m_ctrlPreStage = p:AddToggleControl(locale.get_text("pfm_prestage_only","prestage",false)
	self.m_ctrlRenderWorld = p:AddToggleControl(locale.get_text("pfm_render_world"),"render_world",settings:ShouldRenderWorld())
	self.m_ctrlRenderGameEntities = p:AddToggleControl(locale.get_text("pfm_render_game_objects"),"render_game_entities",settings:ShouldRenderGameObjects())
	self.m_ctrlRenderPlayer = p:AddToggleControl(locale.get_text("pfm_render_player"),"render_player",settings:ShouldRenderPlayer())
	self.m_ctrlFrustumCulling = p:AddToggleControl(locale.get_text("pfm_render_frustum_culling"),"frustum_culling",settings:IsCameraFrustumCullingEnabled())
	self.m_ctrlPVSCulling = p:AddToggleControl(locale.get_text("pfm_render_pvs_culling"),"pvs_culling",settings:IsPvsCullingEnabled())
	self.m_ctrlProgressive = p:AddToggleControl(locale.get_text("pfm_render_progressive"),"progressive",settings:IsProgressive(),function() self.m_ctrlProgressiveRefinement:SetVisible(self.m_ctrlProgressive:IsChecked()) end)
	self.m_ctrlProgressiveRefinement = p:AddToggleControl(locale.get_text("pfm_render_progressive_refinement"),"progressive_refine",settings:IsProgressiveRefinementEnabled())
	self.m_ctrlTransparentSky = p:AddToggleControl(locale.get_text("pfm_render_transparent_sky"),"transparent_sky",settings:ShouldMakeSkyTransparent())

	p:LinkToUDMProperty("denoise",settings,"denoise")
	p:LinkToUDMProperty("render_world",settings,"renderWorld")
	p:LinkToUDMProperty("render_game_entities",settings,"renderGameObjects")
	p:LinkToUDMProperty("render_player",settings,"renderPlayer")
	p:LinkToUDMProperty("frustum_culling",settings,"cameraFrustumCullingEnabled")
	p:LinkToUDMProperty("pvs_culling",settings,"pvsCullingEnabled")
	p:LinkToUDMProperty("progressive",settings,"progressive")
	p:LinkToUDMProperty("progressive_refine",settings,"progressiveRefinementEnabled")
	p:LinkToUDMProperty("transparent_sky",settings,"transparentSky")

	-- Presets
	qualityPreset:AddCallback("OnOptionSelected",function(el,option)
		local preset = presets[option +1]
		if(preset == nil) then return end
		if(preset.samples ~= nil) then self.m_ctrlSamplesPerPixel:SetValue(preset.samples) end
		if(preset.max_transparency_bounces ~= nil) then self.m_ctrlMaxTransparencyBounces:SetValue(preset.max_transparency_bounces) end
		if(preset.emission_strength ~= nil) then self.m_ctrlEmissionStrength:SetValue(preset.emission_strength) end
	end)
	qualityPreset:SelectOption(2)

	self.m_ctrlPreset:AddCallback("OnOptionSelected",function(el,option)
		local opt = self.m_ctrlPreset:GetOptionValue(option)
		if(opt == "standard") then
			self.m_ctrlCamType:SelectOption(tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_PERSPECTIVE))
		elseif(opt == "cinematic") then
			self.m_ctrlCamType:SelectOption(tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_PERSPECTIVE))
		elseif(opt == "vr") then
			self.m_ctrlCamType:SelectOption(tostring(pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA))
			self.m_ctrlPanoramaType:SelectOption(tostring(pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_EQUIRECTANGULAR))
			self.m_ctrlEquirectMode:SelectOption("stereo")
		end
		self:UpdateVROptions()
	end)
	self.m_ctrlPreset:SelectOption(0)

	self:InitializeToneMapControls(p,settings)

	p:ResetControls()
	settings:SetWidth(w)
	settings:SetHeight(h)
end
function gui.PFMRenderPreview:GetResolution()
	local width,height
	local selectedOption = self.m_ctrlResolution:GetSelectedOption()
	local resolution
	if(selectedOption ~= -1) then resolution = self.m_ctrlResolution:GetOptionValue(selectedOption)
	else resolution = self.m_ctrlResolution:GetValue() end
	resolution = string.split(resolution,"x")
	if(resolution[1] ~= nil) then width = tonumber(resolution[1]) or 0 end
	if(resolution[2] ~= nil) then height = tonumber(resolution[2]) or 0 end
	return width,height
end
function gui.PFMRenderPreview:IsInVRMode()
	return tonumber(self.m_ctrlCamType:GetOptionValue(self.m_ctrlCamType:GetSelectedOption())) == pfm.RaytracingRenderJob.Settings.CAM_TYPE_PANORAMA and
		tonumber(self.m_ctrlPanoramaType:GetOptionValue(self.m_ctrlPanoramaType:GetSelectedOption())) == pfm.RaytracingRenderJob.Settings.PANORAMA_TYPE_EQUIRECTANGULAR
		--and self.m_ctrlEquirectMode:GetOptionValue(self.m_ctrlEquirectMode:GetSelectedOption()) == "stereo"
end
function gui.PFMRenderPreview:UpdateViewportMode()
	self.m_rt:GetToneMappedImageElement():SetStereoImage((tonumber(self.m_ctrlPreviewMode:GetOptionValue(self.m_ctrlPreviewMode:GetSelectedOption())) == fudm.PFMRenderSettings.VIEWPORT_MODE_360_RIGHT_EYE) and gui.VRView.STEREO_IMAGE_RIGHT or gui.VRView.STEREO_IMAGE_LEFT)
	self:UpdateVRMode()
end
function gui.PFMRenderPreview:UpdateVROptions()
	local vrMode = self:IsInVRMode()
	self:UpdateVRMode()
	self.m_settingsBox:SetControlVisible("preview_mode",vrMode)

	local newOptions
	local selectedOption
	if(vrMode == false) then
		if(self.m_usesVrResolutions == true) then
			self.m_usesVrResolutions = false
			newOptions = {
				{"1280x720",locale.get_text("pfm_resolution_hd_ready")},
				{"1920x1080",locale.get_text("pfm_resolution_full_hd")},
				{"2560x1440",locale.get_text("pfm_resolution_quad_hd")},
				{"2048x1080",locale.get_text("pfm_resolution_2k")},
				{"3840x2160",locale.get_text("pfm_resolution_4k")},
				{"7680x4320",locale.get_text("pfm_resolution_8k")}
			}
			selectedOption = 1
		end
	else
		if(self.m_usesVrResolutions ~= true) then
			self.m_usesVrResolutions = true
			newOptions = {
				{"1080x1200",locale.get_text("pfm_resolution_vr_vive")},
				{"1440x1600",locale.get_text("pfm_resolution_vr_vive_pro_and_index")},
				{"1440x1700",locale.get_text("pfm_resolution_vr_vive_cosmo")},
				{"1832x1920",locale.get_text("pfm_resolution_vr_oculus_quest")},
				{"1280x1440",locale.get_text("pfm_resolution_vr_oculus_rift_s_and_go")}
			}
			selectedOption = 0
		end
	end
	if(newOptions == nil) then return end
	self.m_ctrlResolution:ClearOptions()
	for _,option in pairs(newOptions) do
		self.m_ctrlResolution:AddOption(option[2],option[1])
	end
	self.m_ctrlResolution:SelectOption(selectedOption)
end
function gui.PFMRenderPreview:InitializeControls()
	gui.PFMBaseViewport.InitializeControls(self)

	local controls = gui.create("WIHBox",self.m_vpContents)
	--controls:SetHeight(self:GetHeight() -self.m_aspectRatioWrapper:GetBottom())
	self.m_controls = controls

	self.m_btCancel = gui.PFMButton.create(controls,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		if(self:IsRendering()) then
			self:CancelRendering()
			return
		end
		self.m_btCancel:SetVisible(false)
		self.m_btStop:SetVisible(false)
		self.m_renderBtContainer:SetVisible(true)
	end)
	self.m_btCancel:SetText(locale.get_text("pfm_cancel_rendering"))
	-- self.m_btCancel:SetTooltip(locale.get_text("pfm_refresh_preview"))
	self.m_btCancel:SetVisible(false)

	self.m_btStop = gui.PFMButton.create(controls,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		local scene = self.m_rt:GetRenderScene()
		if(scene == nil or scene:IsValid() == false) then return end
		scene:StopRendering()
		self.m_btCancel:SetVisible(false)
		self.m_btStop:SetVisible(false)
	end)
	self.m_btStop:SetText(locale.get_text("pfm_stop_rendering"))
	self.m_btStop:SetVisible(false)

	local btContainer = gui.create("WIHBox",controls)
	self.m_renderBtContainer = btContainer
	self.m_btRefreshPreview = gui.PFMButton.create(btContainer,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		self:Refresh(true)
	end)
	self.m_btRefreshPreview:SetText(locale.get_text("pfm_render_preview"))
	self.m_btRefreshPreview:SetTooltip(locale.get_text("pfm_refresh_preview"))

	gui.create("WIBase",btContainer,0,0,5,1) -- Gap

	self.m_btRefresh = gui.PFMButton.create(btContainer,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		self:Refresh()
	end)
	self.m_btRefresh:SetText(locale.get_text("pfm_render_image"))
	self.m_btRefresh:SetTooltip(locale.get_text("pfm_render_frame"))

	gui.create("WIBase",btContainer,0,0,5,1) -- Gap

	self.m_btPrepare = gui.PFMButton.create(btContainer,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		self:Refresh(false,true)
	end)
	self.m_btPrepare:SetText(locale.get_text("pfm_create_render_job"))
	self.m_btPrepare:SetTooltip(locale.get_text("pfm_create_render_job_desc"))

	gui.create("WIBase",controls,0,0,5,1) -- Gap

	self.m_btOpenOutputDir = gui.PFMButton.create(controls,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		local path = util.Path(util.get_addon_path() .. "render/" .. self:GetCurrentFrameFilePath())
		util.open_path_in_explorer(path:GetPath(),path:GetFileName() .. "." .. util.get_image_format_file_extension(self.m_rt:GetImageSaveFormat()))
	end)
	self.m_btOpenOutputDir:SetText(locale.get_text("pfm_open_output_dir"))

	--[[self.m_btApplyPostProcessing = gui.PFMButton.create(controls,"gui/pfm/icon_cp_generic_button_large","gui/pfm/icon_cp_generic_button_large_activated",function()
		local filmmaker = tool.get_filmmaker()
		local frameStart = filmmaker:GetClampedFrameOffset()
		local frameEnd = math.max(math.min(frameStart +self.m_ctrlFrameCount:GetValue() -1,filmmaker:GetLastFrameIndex()),frameStart)
		self.m_applyPostProcessing = {
			startFrame = frameStart,
			endFrame = frameEnd,
			curFrame = frameStart,
			nextUpdate = time.cur_time() +4 -- TODO: A smaller update time can cause discrepancies between the game frame and the render frame. Why? FIXME
		}
		filmmaker:GoToFrame(frameStart)
		self:EnableThinking()
	end)
	self.m_btApplyPostProcessing:SetText(locale.get_text("pfm_apply_post_processing"))]]

	controls:Update()
end
function gui.PFMRenderPreview:OnThink()
	gui.PFMBaseViewport.OnThink(self)

	if(self.m_applyPostProcessing == nil) then return end

	local t = time.cur_time()
	if(t < self.m_applyPostProcessing.nextUpdate) then return end
	self.m_applyPostProcessing.nextUpdate = time.cur_time() +4

	-- self:UpdateDepthOfField()
	local filmmaker = tool.get_filmmaker()
	local framePath = self:GetFrameFilePath(filmmaker:GetClampedFrameOffset())
	local outputPath = "render/" .. framePath
	self.m_rt:SaveImage(outputPath)

	local nextFrame = self.m_applyPostProcessing.curFrame +1
	self.m_applyPostProcessing.curFrame = nextFrame
	if(nextFrame > self.m_applyPostProcessing.endFrame) then
		self.m_applyPostProcessing = nil
		self:DisableThinking()
		return
	end
	filmmaker:GoToFrame(nextFrame)
end
function gui.PFMRenderPreview:GetFrameFilePath(frameIndex)
	local filmmaker = tool.get_filmmaker()
	local frameOffset = filmmaker:GetActiveFilmClipFrameOffset(frameIndex)
	if(frameOffset == nil) then return end
	frameOffset = filmmaker:GetClampedFrameOffset(frameOffset)

	local project = filmmaker:GetProject()
	local filmClip = filmmaker:GetActiveFilmClip()
	local projectName = project:GetName()
	local filmClipName = filmClip:GetName()
	if(#projectName == 0) then projectName = "unnamed" end
	if(#filmClipName == 0) then filmClipName = "unnamed" end
	return projectName .. "/" .. filmClipName .. "/frame" .. string.fill_zeroes(tostring(frameOffset +1),4)
end
function gui.PFMRenderPreview:GetCurrentFrameFilePath()
	return self:GetFrameFilePath(tool.get_filmmaker():GetFrameOffset())
end
function gui.PFMRenderPreview:IsRendering() return self.m_rt:IsRendering() end
function gui.PFMRenderPreview:GetRenderSettings(preview,prepareOnly)
	preview = preview or false
	local settings = self.m_rt:GetRenderSettings()
	local renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_COMBINED

	local selectedRenderMode = tonumber(self.m_ctrlRenderMode:GetValue())
	if(selectedRenderMode == fudm.PFMRenderSettings.MODE_COMBINED) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_COMBINED
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_ALBEDO) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_ALBEDO
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_NORMALS) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_NORMALS
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DEPTH) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DEPTH
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_ALPHA) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_ALPHA
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_GEOMETRY_NORMAL) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_GEOMETRY_NORMAL
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_SHADING_NORMAL) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_SHADING_NORMAL
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_DIFFUSE
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE_REFLECT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_DIFFUSE_REFLECT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_DIFFUSE_TRANSMIT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_DIFFUSE_TRANSMIT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_GLOSSY
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY_REFLECT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_GLOSSY_REFLECT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_DIRECT_GLOSSY_TRANSMIT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_DIRECT_GLOSSY_TRANSMIT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_EMISSION) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_EMISSION
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_DIFFUSE
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE_REFLECT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_DIFFUSE_REFLECT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_DIFFUSE_TRANSMIT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_DIFFUSE_TRANSMIT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_GLOSSY
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY_REFLECT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_GLOSSY_REFLECT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_GLOSSY_TRANSMIT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_GLOSSY_TRANSMIT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_SPECULAR
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR_REFLECT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_SPECULAR_REFLECT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_INDIRECT_SPECULAR_TRANSMIT) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_INDIRECT_SPECULAR_TRANSMIT
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_UV) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_UV
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_IRRADIANCE) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_IRRADIANCE
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_NOISE) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_NOISE
	elseif(selectedRenderMode == fudm.PFMRenderSettings.MODE_CAUSTIC) then renderMode = pfm.RaytracingRenderJob.Settings.RENDER_MODE_CAUSTIC end

	local deviceType = pfm.RaytracingRenderJob.Settings.DEVICE_TYPE_GPU
	local selectedDeviceType = tonumber(self.m_ctrlDeviceType:GetValue())
	if(selectedDeviceType == fudm.PFMRenderSettings.DEVICE_TYPE_CPU) then deviceType = pfm.RaytracingRenderJob.Settings.DEVICE_TYPE_CPU
	elseif(selectedDeviceType == fudm.PFMRenderSettings.DEVICE_TYPE_GPU) then deviceType = pfm.RaytracingRenderJob.Settings.DEVICE_TYPE_GPU end

	local width,height = self:GetResolution()

	local previewQuality = tonumber(self.m_ctrlPreviewQuality:GetOptionValue(self.m_ctrlPreviewQuality:GetSelectedOption()))
	local samples
	if(preview) then
		local qualityResolutions = {
			[0] = 512,
			[1] = 512,
			[2] = 1024
		}
		local qualitySamples = {
			[0] = 4,
			[1] = 8,
			[2] = 16
		}
		samples = qualitySamples[previewQuality]
		local aspectRatio = width /height
		if(width > height) then
			height = qualityResolutions[previewQuality]
			width = height *aspectRatio
			if((width %1.0) > 0.001) then
				-- Round to the nearest value dividable by 2
				if((math.floor(width) %2.0) <= 0.001) then width = math.floor(width)
				else width = math.ceil(width) end
			end
		else
			width = qualityResolutions[previewQuality]
			height = width /aspectRatio
			if((height %1.0) > 0.001) then
				-- Round to the nearest value dividable by 2
				if((math.floor(height) %2.0) <= 0.001) then height = math.floor(height)
				else height = math.ceil(height) end
			end
		end
	end

	local denoiseMode
	if(self.m_ctrlDenoise:IsChecked() == false) then denoiseMode = pfm.RaytracingRenderJob.Settings.DENOISE_MODE_NONE
	else denoiseMode = (preview and previewQuality == 0) and pfm.RaytracingRenderJob.Settings.DENOISE_MODE_FAST or pfm.RaytracingRenderJob.Settings.DENOISE_MODE_DETAILED end

	local progressiveRefinement = self.m_ctrlProgressiveRefinement:IsChecked()
	settings:SetRenderMode(renderMode)
	settings:SetRenderEngine(self.m_ctrlRenderEngine:GetValue())
	settings:SetSamples(samples or self.m_ctrlSamplesPerPixel:GetValue())
	settings:SetSky(self.m_ctrlSkyOverride:GetValue())
	settings:SetSkyStrength(self.m_ctrlSkyStrength:GetValue())
	settings:SetEmissionStrength(self.m_ctrlEmissionStrength:GetValue())
	settings:SetSkyYaw(self.m_ctrlSkyYaw:GetValue())
	settings:SetMaxTransparencyBounces(self.m_ctrlMaxTransparencyBounces:GetValue())
	settings:SetLightIntensityFactor(self.m_ctrlLightIntensityFactor:GetValue())
	settings:SetFrameCount(preview and 1 or self.m_ctrlFrameCount:GetValue())
	settings:SetPreStageOnly(prepareOnly == true)
	settings:SetTransparentSky(self.m_ctrlTransparentSky:IsChecked())
	settings:SetDenoiseMode(denoiseMode)
	settings:SetDeviceType(deviceType)
	settings:SetRenderWorld(self.m_ctrlRenderWorld:IsChecked())
	settings:SetRenderGameEntities(self.m_ctrlRenderGameEntities:IsChecked())
	settings:SetRenderPlayer(self.m_ctrlRenderPlayer:IsChecked())
	settings:SetCameraFrustumCullingEnabled(self.m_ctrlFrustumCulling:IsChecked())
	settings:SetPVSCullingEnabled(self.m_ctrlPVSCulling:IsChecked())
	settings:SetProgressive(self.m_ctrlProgressive:IsChecked())
	settings:SetUseProgressiveRefinement(progressiveRefinement)
	settings:SetCamType(tonumber(self.m_ctrlCamType:GetValue()))
	settings:SetPanoramaType(tonumber(self.m_ctrlPanoramaType:GetValue()))
	settings:SetPanoramaHorizontalRange(tonumber(self.m_ctrlPanoramaRange:GetOptionValue(self.m_ctrlPanoramaRange:GetSelectedOption())))
	settings:SetStereoscopic(self.m_ctrlEquirectMode:GetOptionValue(self.m_ctrlEquirectMode:GetSelectedOption()) == "stereo")
	settings:SetWidth(width)
	settings:SetHeight(height)
	settings:SetExposure(self.m_ctrlExposure:GetValue())
	settings:SetHDROutput(tonumber(self.m_ctrlOutputFormat:GetOptionValue(self.m_ctrlOutputFormat:GetSelectedOption())) == util.IMAGE_FORMAT_HDR)

	settings:SetColorTransform(self.m_ctrlColorTransform:GetOptionValue(self.m_ctrlColorTransform:GetSelectedOption()))
	settings:SetColorTransformLook(self.m_ctrlColorTransformLook:GetOptionValue(self.m_ctrlColorTransformLook:GetSelectedOption()))
	return settings
end
function gui.PFMRenderPreview:CancelRendering()
	if(self:IsRendering()) then self.m_rt:CancelRendering() end
	console.run("cl_max_fps","-1") -- Unclamp FPS
end
function gui.PFMRenderPreview:Refresh(preview,prepareOnly)
	self:CancelRendering()
	tool.get_filmmaker():StopLiveRaytracing()
	self.m_btCancel:SetVisible(true)
	self.m_renderBtContainer:SetVisible(false)

	preview = preview or false
	local settings = self:GetRenderSettings(preview,prepareOnly)

	if(progressiveRefinement) then self.m_btStop:SetVisible(true) end

	self.m_renderedImageType = gui.PFMRenderPreview.IMAGE_TYPE_FLAT
	if(self:IsInVRMode()) then
		if(settings:IsStereoscopic()) then self.m_renderedImageType = gui.PFMRenderPreview.IMAGE_TYPE_STEREO
		else self.m_renderedImageType = gui.PFMRenderPreview.IMAGE_TYPE_MONO end
	end

	console.run("cl_max_fps","4") -- Clamp max fps to make more resources available for the renderer
	self.m_rt:Refresh(preview,function(rtJob)
		self:CallCallbacks("InitializeRender",rtJob,settings,preview)
	end)
	self:UpdateViewport(settings)
end
gui.register("WIPFMRenderPreview",gui.PFMRenderPreview)
