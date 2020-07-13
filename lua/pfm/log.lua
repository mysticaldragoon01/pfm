--[[
    Copyright (C) 2019  Florian Weischer

    This Source Code Form is subject to the terms of the Mozilla Public
    License, v. 2.0. If a copy of the MPL was not distributed with this
    file, You can obtain one at http://mozilla.org/MPL/2.0/.
]]

pfm = pfm or {}

pfm.LOG_SEVERITY_NORMAL = 0
pfm.LOG_SEVERITY_WARNING = 1
pfm.LOG_SEVERITY_ERROR = 2
pfm.LOG_SEVERITY_CRITICAL = 3

pfm.MAX_LOG_CATEGORIES = 30
local g_enabledCategories = bit.lshift(1,pfm.MAX_LOG_CATEGORIES) -1 -- Enable all call categories by default
pfm.is_log_category_enabled = function(categories)
	return categories == 0 or bit.band(categories,g_enabledCategories) ~= 0
end

pfm.set_log_category_enabled = function(category,enabled)
	g_enabledCategories = math.set_flag_enabled(g_enabledCategories,category,enabled)
end

pfm.set_enabled_log_categories = function(categories)
	g_enabledCategories = categories
end

pfm.log = function(msg,categories,severity)
	severity = severity or pfm.LOG_SEVERITY_NORMAL
	categories = categories or pfm.LOG_CATEGORY_PFM
	if(pfm.is_log_category_enabled(categories) == false) then return false end
	msg = "[PFM] " .. msg
	if(severity == pfm.LOG_SEVERITY_NORMAL) then console.print_messageln(msg)
	elseif(severity == pfm.LOG_SEVERITY_WARNING) then console.print_warning(msg)
	elseif(severity == pfm.LOG_SEVERITY_ERROR) then console.print_error(msg)
	elseif(severity == pfm.LOG_SEVERITY_CRITICAL) then console.print_error(msg)
	else return false end
	return true
end

pfm.error = function(msg)
	local severity = pfm.LOG_SEVERITY_ERROR
	local category = 0
	local r = pfm.log(msg,category,severity)
	error(msg)
	return r
end

local g_logCategories = {}
pfm.register_log_category = function(name)
	local catName = "LOG_CATEGORY_" .. name:upper()
	if(pfm[catName] ~= nil) then return pfm[catName] end
	if(#g_logCategories >= pfm.MAX_LOG_CATEGORIES) then
		console.print_warning("Unable to register log category '" .. name .. "': Max log category count of " .. pfm.MAX_LOG_CATEGORIES .. " has been exceeded!")
		return -1
	end
	local catId = bit.lshift(1,#g_logCategories)
	table.insert(g_logCategories,{
		name = name
	})
	pfm[catName] = catId
	return catId
end

pfm.register_log_category("pfm")
pfm.register_log_category("pfm_game")
pfm.register_log_category("pfm_interface")
pfm.register_log_category("pfm_render")
