if(gui.skin_exists("pfm") == true) then return end

-------------------------------------------
------------ START OF SETTINGS ------------
-------------------------------------------

local t = {}
t.BACKGROUND_COLOR_DEFAULT = Color(38,38,38,255)
t.BACKGROUND_COLOR_HOVER = Color(48,48,48,255)
t.BACKGROUND_COLOR_SELECTED = Color(58,58,58,255)

-------------------------------------------
------------- END OF SETTINGS -------------
-------------------------------------------

local function add_skin_element(pElement,el)
	if(pElement.m_tSkinElements == nil) then pElement.m_tSkinElements = {} end
	table.insert(pElement.m_tSkinElements,el)
end

local function clear_element(GUI,pElement)
	if(pElement.m_tSkinElements ~= nil) then
		for _,el in ipairs(pElement.m_tSkinElements) do
			if(el:IsValid()) then el:Remove() end
		end
		pElement.m_tSkinElements = nil
	end
end

local function create_gradient(colStart,colEnd)
	return vulkan.create_gradient_texture(128,64,vulkan.FORMAT_R8G8B8A8_UNORM,Vector2(0,-1),{
		{offset = 0.0,color = colStart},
		{offset = 1.0,color = colEnd}
	})
end

--[[t.BACKGROUND_GRADIENT = function(t)
	t._BACKGROUND_GRADIENT = t._BACKGROUND_GRADIENT or create_gradient(t.BACKGROUND_GRADIENT_START,t.BACKGROUND_GRADIENT_END)
	return t._BACKGROUND_GRADIENT
end]]

local skin = {}
------------ WIButton ------------
skin["timeline_clip_film"] = {
	Initialize = function(GUI,pElement)
		local elBg = pElement:FindChildByName("background")
		if(elBg ~= nil) then elBg:SetColor(Color(47,47,121)) end
	end
}
skin["timeline_clip_audio"] = {
	Initialize = function(GUI,pElement)
		local elBg = pElement:FindChildByName("background")
		if(elBg ~= nil) then elBg:SetColor(Color(50,127,50)) end
	end
}
skin["timeline_clip_overlay"] = {
	Initialize = function(GUI,pElement)
		local elBg = pElement:FindChildByName("background")
		if(elBg ~= nil) then elBg:SetColor(Color(122,48,48)) end
	end
}
-----------------------------------------
gui.register_skin("pfm",t,skin,"default")
