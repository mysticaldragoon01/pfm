--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

util.register_class("ents.PFMModel",BaseEntityComponent)

function ents.PFMModel:Initialize()
	BaseEntityComponent.Initialize(self)

	self:AddEntityComponent(ents.COMPONENT_TRANSFORM)
	self:AddEntityComponent(ents.COMPONENT_MODEL)
	local renderC = self:AddEntityComponent(ents.COMPONENT_RENDER)
	self:AddEntityComponent("pfm_actor")
	if(renderC ~= nil) then
		renderC:SetCastShadows(true)
	end

	self.m_listeners = {}
end
function ents.PFMModel:OnRemove()
	if(util.is_valid(self.m_cbOnSkeletonUpdated)) then self.m_cbOnSkeletonUpdated:Remove() end
	for _,cb in ipairs(self.m_listeners) do
		if(cb:IsValid()) then cb:Remove() end
	end
end
function ents.PFMModel:OnEntitySpawn()
	local modelData = self:GetModelData()
	local ent = self:GetEntity()
	local mdlC = ent:GetComponent(ents.COMPONENT_MODEL)
	local mdl = (mdlC ~= nil) and mdlC:GetModel() or nil
	if(mdl == nil) then return end
	local bones = modelData:GetBoneList():GetTable()
	local animSetC = (#bones > 0) and self:AddEntityComponent("pfm_animation_set") or nil
	if(animSetC == nil) then return end -- TODO: What if flexes, but no bones? (Animation component shouldn't be needed in this case)

	local animC = ent:GetComponent(ents.COMPONENT_ANIMATED)
	if(animC ~= nil) then
		local function apply_bone_transforms(entInvPose,bone)
			local boneName = bone:GetName()
			local boneId = mdl:LookupBone(boneName) -- TODO: Cache this
			if(boneId ~= -1) then
				local pose = entInvPose *bone:GetTransform():GetAbsolutePose()
				animC:SetEffectiveBoneTransform(boneId,pose)
			end

			for _,child in ipairs(bone:GetChildBones():GetTable()) do
				apply_bone_transforms(entInvPose,child)
			end
		end

		self.m_cbOnSkeletonUpdated = animC:AddEventCallback(ents.AnimatedComponent.EVENT_ON_SKELETON_UPDATED,function()
			local entInvPose = ent:GetPose():GetInverse()
			entInvPose:SetScale(Vector(1,1,1)) -- Entity scale will be applied separately
			for _,bone in ipairs(modelData:GetRootBones():GetTable()) do
				apply_bone_transforms(entInvPose,bone)
			end
		end)
		--[[self.m_cbOnSkeletonUpdated = animC:AddEventCallback(ents.AnimatedComponent.EVENT_ON_SKELETON_UPDATED,function()
			local testPose = phys.Transform()
			local function iterate_skeleton(bone,parentPose)
				local boneName = bone:GetName()
				local boneId = mdl:LookupBone(boneName) -- TODO: Cache bone id
				local pose = parentPose *testPose
				for _,child in ipairs(bone:GetChildBones():GetTable()) do
					iterate_skeleton(child,pose)
				end
			end
			local pose = phys.ScaledTransform()
			for _,bone in ipairs(modelData:GetRootBones():GetTable()) do
				iterate_skeleton(bone,pose)
			end
		end)]]
	end

--[[
bip_ponytail01  55
bip_ponytail02  56
bip_ponytail03  57
]]
	print("-----------",ent)
	for _,bone in ipairs(bones) do
		bone = bone:GetTarget()
		local boneName = bone:GetName()
		local boneId = mdl:LookupBone(boneName)
		print(boneName,boneId)
		if(boneId ~= -1) then
			local t = bone:GetTransform() -- TODO: Remove this
			local pose = t:GetPose()
			animSetC:SetBonePos(boneId,pose:GetOrigin())
			animSetC:SetBoneRot(boneId,pose:GetRotation())
			--[[table.insert(self.m_listeners,t:GetPositionAttr():AddChangeListener(function(newPos)
				print("Pos: ",boneName,boneId,newPos)
				animSetC:SetBonePos(boneId,newPos)
			end))
			table.insert(self.m_listeners,t:GetRotationAttr():AddChangeListener(function(newRot)
				print("Rot: ",boneName,boneId,newRot)
				animSetC:SetBoneRot(boneId,newRot)
			end))]]
		else
			pfm.log("Unknown bone '" .. boneName .. "' for actor with model '" .. mdl:GetName() .. "'! Bone pose will be ignored...",pfm.LOG_CATEGORY_PFM_GAME,pfm.LOG_SEVERITY_WARNING)
		end
	end

	local flexWeights = modelData:GetFlexWeights():GetTable()
	local flexNames = modelData:GetFlexControllerNames():GetTable()
	for i,name in ipairs(flexNames) do
		name = name:GetValue()
		if(#name > 0) then
			local weight = flexWeights[i]
			local fcId = mdl:LookupFlexController(name)
			if(fcId ~= -1) then
				animSetC:SetFlexController(fcId,weight:GetValue())
				table.insert(self.m_listeners,weight:AddChangeListener(function(newValue)
					if(animSetC:IsValid()) then
						animSetC:SetFlexController(fcId,newValue)
					end
				end))
			else
				pfm.log("Unknown flex controller '" .. name .. "' for actor with model '" .. mdl:GetName() .. "'! Flex controller will be ignored...",pfm.LOG_CATEGORY_PFM_GAME,pfm.LOG_SEVERITY_WARNING)
			end
		end
	end
end
function ents.PFMModel:GetModelData() return self.m_mdlInfo end
function ents.PFMModel:GetActorData() return self.m_actorData end
function ents.PFMModel:Setup(actorData,mdlInfo)
	self.m_mdlInfo = mdlInfo
	self.m_actorData = actorData
	local ent = self:GetEntity()
	local mdlC = ent:GetComponent(ents.COMPONENT_MODEL)
	if(mdlC == nil) then return end
	local mdlName = mdlInfo:GetModelName()
	mdlC:SetModel(mdlName)
	mdlC:SetSkin(mdlInfo:GetSkin())
end
ents.COMPONENT_PFM_MODEL = ents.register_component("pfm_model",ents.PFMModel)
