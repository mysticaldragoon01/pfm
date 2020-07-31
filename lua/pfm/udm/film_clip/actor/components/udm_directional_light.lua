--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("udm_entity_component.lua")

udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT = udm.register_type("PFMDirectionalLight",{udm.PFMEntityComponent},true)

udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"color",udm.Color(Color.White))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"intensity",udm.Float(1000.0))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"intensityType",udm.UInt8(ents.LightComponent.INTENSITY_TYPE_CANDELA))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"falloffExponent",udm.Float(1.0))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"maxDistance",udm.Float(1000.0))
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"castShadows",udm.Bool(false),{
	getter = "ShouldCastShadows"
})
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"volumetric",udm.Bool(false),{
	getter = "IsVolumetric"
})
udm.register_element_property(udm.ELEMENT_TYPE_PFM_DIRECTIONAL_LIGHT,"volumetricIntensity",udm.Float(1.0))

function udm.PFMDirectionalLight:GetComponentName() return "pfm_light_directional" end
function udm.PFMDirectionalLight:GetIconMaterial() return "gui/pfm/icon_light_item" end

function udm.PFMDirectionalLight:SetupControls(actorEditor,itemComponent)
	actorEditor:AddControl(self,itemComponent,{
		name = locale.get_text("intensity"),
		property = "intensity",
		min = 0.0,
		max = 10000.0,
		default = 2000.0
	})
	actorEditor:AddControl(self,itemComponent,{
		name = locale.get_text("radius"),
		property = "maxDistance",
		min = 0.0,
		max = 1000.0,
		default = 100.0
	})
	actorEditor:AddControl(self,itemComponent,{
		name = locale.get_text("red"),
		get = function(light) return light:GetColor():ToVector4().x end,
		set = function(light,red)
			col = light:GetColor():ToVector4()
			col.x = red
			light:SetColor(Color(col))
		end,
		min = 0.0,
		max = 1.0,
		default = 1.0
	})
	actorEditor:AddControl(self,itemComponent,{
		name = locale.get_text("green"),
		get = function(light) return light:GetColor():ToVector4().y end,
		set = function(light,green)
			col = light:GetColor():ToVector4()
			col.y = green
			light:SetColor(Color(col))
		end,
		min = 0.0,
		max = 1.0,
		default = 1.0
	})
	actorEditor:AddControl(self,itemComponent,{
		name = locale.get_text("blue"),
		get = function(light) return light:GetColor():ToVector4().z end,
		set = function(light,blue)
			col = light:GetColor():ToVector4()
			col.z = blue
			light:SetColor(Color(col))
		end,
		min = 0.0,
		max = 1.0,
		default = 1.0
	})
end
