local util = { }
local vars = require "Guide42.guide42_variables"


function util.safe_is_enabled(node, steps)
	local parent = gui.get_parent(node)
	if gui.is_enabled(node) then
		if parent then
			return util.safe_is_enabled(parent)
		else
			return true
		end
	else
		return false
	end
end

function util.safe_get_node(node)
	local temp, data = pcall(gui.get_node, node)
	if temp then
		return data
	else
		print ("Node", node, "not found")
		return nil
	end
end

function util.hit_node(node, x, y)
	return util.safe_is_enabled(node) and gui.pick_node(node, x, y)
end

function util.clamp(x, min, max)
	return math.max(min, math.min(x, max))
end


return util