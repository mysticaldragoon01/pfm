--[[
    Copyright (C) 2021 Silverlan

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

include("material.lua")

sfm.register_element_type("GameModel")
sfm.link_dmx_type("DmeGameModel",sfm.GameModel)

sfm.register_element_type("Transform") -- Predeclaration
sfm.register_element_type("GlobalFlexControllerOperator") -- Predeclaration

sfm.BaseElement.RegisterProperty(sfm.GameModel,"transform",sfm.Transform)
sfm.BaseElement.RegisterProperty(sfm.GameModel,"overrideParent")
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"overridePos")
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"overrideRot")
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"modelName","")
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"skin",0)
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"body",0)
sfm.BaseElement.RegisterArray(sfm.GameModel,"children",sfm.Dag)
sfm.BaseElement.RegisterArray(sfm.GameModel,"bones",sfm.Transform)
sfm.BaseElement.RegisterArray(sfm.GameModel,"flexnames","",{
	getterName = "GetFlexNames",
	setterName = "SetFlexNames"
})
sfm.BaseElement.RegisterArray(sfm.GameModel,"flexWeights",0.0)
sfm.BaseElement.RegisterArray(sfm.GameModel,"globalFlexControllers",sfm.GlobalFlexControllerOperator)
sfm.BaseElement.RegisterArray(sfm.GameModel,"materials",sfm.Material)
sfm.BaseElement.RegisterAttribute(sfm.GameModel,"visible",false,{
	getterName = "IsVisible"
})

function sfm.GameModel:GetPragmaModelPath()
	local mdlName = self:GetModelName()
	if(#mdlName > 0) then
		mdlName = file.remove_file_extension(mdlName:sub(7)) -- Remove "models/"-prefix
		if(#mdlName > 0) then mdlName = mdlName .. ".wmd" end
	end
	return mdlName
end
