local scope = { }
local util = require "Guide42.util"
local vars = require "Guide42.guide42_variables"
local meta = { }

meta.__index = meta

function set_state_elements(self)
	local temp = gui.get_color(self.point_node)
	temp.w = ((self.no_point and 0) or 1)
	gui.set_color(self.point_node, temp)
	
	temp = gui.get_color(self.background_node)
	temp.w = ((self.no_background and 0) or 1)
	gui.set_color(self.background_node, temp)
	
	temp = gui.get_color(self.slider_node)
	temp.w = ((self.no_slider and 0) or 1)
	gui.set_color(self.slider_node, temp)
end

function scope.init (id, settings) 
	local obj = { 
		background_node = util.safe_get_node(id .. "/background"),
		slider_node = util.safe_get_node(id .. "/slider"),
		point_node = util.safe_get_node(id .. "/point"),
		
		no_point = settings.no_point,
		no_background = settings.no_background,
		no_slider = settings.no_slider,
		
		vertical = not settings.horizontal,
		
		min_value = settings.min_value or 0,
		max_value = settings.max_value or 1,
		
		moveable = settings.moveable,
		
		acceleration = settings.acceleration or 1
	}

	setmetatable(obj, meta)
	
	obj.size = gui.get_size(obj.slider_node)
	
	gui.set_position(obj.slider_node, vmath.vector3(0, 0, 0)) 
	
	set_state_elements(obj)
	
	obj.max_size = gui.get_size(obj.background_node)
	if (obj.vertical) then
		gui.set_pivot(obj.slider_node, gui.PIVOT_S)
		gui.set_pivot(obj.background_node, gui.PIVOT_S)
		obj.max_size = obj.max_size.y
	else
		gui.set_pivot(obj.slider_node, gui.PIVOT_W)
		gui.set_pivot(obj.background_node, gui.PIVOT_W)
		obj.max_size = obj.max_size.x
	end
	
	
	obj:set_value(obj.min_value)
	return obj
end

function get_value(value, min, max)
	if (min == max) then
		return 1
	end
	return (value -  min) / (max - min)
end

function size_of_point(self)
	local temp = gui.get_size(self.point_node)
	return (self.vertical and temp.y) or temp.x
end

function meta:set_value(value)
	value = util.clamp(value, self.min_value, self.max_value)
	self.value = value
	local size = size_of_point(self)/2
	local temp = get_value(value, self.min_value, self.max_value) * (self.max_size - size * 2) + size
	if (self.vertical) then
		self.size.y = temp
		gui.set_position(self.point_node, vmath.vector3(0, temp, 0))
	else
		self.size.x = temp
		gui.set_position(self.point_node, vmath.vector3(temp, 0, 0))
	end 
	gui.set_size(self.slider_node, self.size)
end


function meta:get_value()
	return self.value
end

function meta:on_input(action_id, action)
	if (not self.moveable) then
		return
	end
		
	if (action_id == vars.touch) then
		if (gui.pick_node(self.point_node, action.x, action.y)) then	
			if (action.pressed) then
				self.touched = true
			end
			return { value = self.value } 
		end
		
		if (self.touched) then
			local val = ((self.vertical and action.dy) or action.dx) * self.acceleration
			val = (val / self.max_size) * (self.max_value - self.min_value)
			self:set_value(self.value + val)
			if (action.released) then
				self.touched = false
			end
			return { value = self.value } 
		end
		
		
	end
end

function meta:change_min_max(new_min, new_max)
	self.min_value = new_min
	self.max_value = new_max
	self:set_value(self.value)
end

function meta:disable()
	gui.set_enabled(self.point_node, false)
	gui.set_enabled(self.background_node, false)
	gui.set_enabled(self.slider_node, false)
end

function meta:enable()
	set_state_elements(self)
end


return scope