local scope = { }
local util = require "Guide42.util"
local vars = require "Guide42.guide42_variables"
local meta = { }
meta.__index = meta

local function sign (x)
	if (x > 0) then
		return 1
	end
	return -1
end

local function clamp (x, min, max)
	return math.max(min, math.min(x, max))
end

local function is_entry(x, min, max)
	return x <= min or x >= max
end

local function set_plane_position(self)
	local min
	local max
	local temp
	if (self.vertical) then
		max = - self.object_size.y * 0.5 - self.padding_vertical
		
		if (#self.objects == 0) then
			max = - self.padding_vertical
			min = max
		else
			min = - self.padding_vertical - self.object_size.y * 0.5 - (self.object_size.y + self.between) * (#self.objects - 1)
		end
		temp = is_entry(self.position.y, min, max)
		self.position.y = clamp(self.position.y, min, max)
	else
		max = - self.object_size.x * 0.5 - self.padding_horizontal
		
		if (#self.objects == 0) then
		 	max = - self.padding_horizontal
			min = max
		else
			min = - self.padding_horizontal - self.object_size.x * 0.5 - (self.object_size.x + self.between) * (#self.objects - 1)
		end
		temp = is_entry(self.position.x, min, max)
		self.position.x = clamp(self.position.x, min, max)
	end	
	gui.set_position(self.objects_plane, self.position)
	return temp
end


local function set_value(self)
	if #self.objects == 0 then
		return nil
	end
	
	if self.vertical then
		return 1 + (math.abs(self.position.y) - self.object_size.y * 0.5 - self.padding_vertical) / (self.object_size.y + self.between)
	end
	
	self.value = 1 + (math.abs(self.position.x) - self.object_size.x * 0.5 - self.padding_horizontal) / (self.object_size.x + self.between)
	
end


local function get_node_position(self, num)
	num = (num and (num - 1)) or #self.objects
	if self.vertical then
		return vmath.vector3(0, (self.object_size.y + self.between) * (num) + self.object_size.y * 0.5 + self.padding_vertical, 0)
	end
	
	return vmath.vector3((self.object_size.x + self.between) * (num) + self.object_size.x * 0.5 + self.padding_horizontal, 0, 0)
end



local function set_plane_size(self)
	local size = gui.get_size(self.objects_plane)
	
	if (self.vertical) then
		size.y = (self.object_size.y + self.between) * (#self.objects) - ((#self.objects > 0 and self.between) or 0)  + self.padding_vertical * 2
	else
		size.x = (self.object_size.x + self.between) * (#self.objects) - ((#self.objects > 0 and self.between) or 0) + self.padding_horizontal * 2
	end
	gui.set_size(self.objects_plane, size)
end

local function update_plane(self)
	set_plane_size(self)
	set_plane_position(self)
	set_value(self)
end


function scope.init(id, settings)
	local obj = { 
		clip_plane = util.safe_get_node(id..'/clip_plane'),
		objects_plane = util.safe_get_node(id..'/objects_plane'),
		object_size = gui.get_size(settings.clone),
		
		clone = settings.clone,
		
		vertical = not settings.horizontal,
		
		between = settings.between or 150,
		padding_horizontal = settings.padding_horizontal or 50,
		padding_vertical = settings.padding_vertical or 50,
		
		touch_acceleration = settings.touch_acceleration or 1,
		max_speed = settings.max_speed,
		min_speed = settings.min_speed or 10,
		acceleration_down = settings.acceleration_down or 150,
		touch_speed_border = settings.touch_speed_border or 5,
		
		
		speed = 0,
		value = nil,
		objects = { },
		nodes = { },
		nodes_on_screen = { },
		clone_name = settings.clone_name or "guide42_scroll",
		bind = settings.bind
		
	}
	
	obj.position = gui.get_position(obj.objects_plane)

	
	gui.set_enabled(obj.clone, false)
	
	
	if (obj.vertical) then
		gui.set_pivot(obj.objects_plane, gui.PIVOT_S)
	else
		gui.set_pivot(obj.objects_plane, gui.PIVOT_W)
	end
	
	
	setmetatable(obj, meta)
	update_plane(obj)
	return obj
end
	




function meta:update(dt, on_change)
	if (#self.objects == 0) then
		return
	end
	
	if (self.moved) then
		
		local temp = self.speed * dt  - self.acceleration_down * sign(self.speed) * dt * dt / 2	
		
		if (self.vertical) then
			self.position.y = self.position.y + temp
		else
			self.position.x = self.position.x + temp		
		end
		
		set_plane_position(self)
		
		if (set_plane_position(self)) then
			self:stop()
		end
		
		set_value(self) 
		
		self.speed = self.speed - self.acceleration_down * dt * sign(self.speed)	
		
		
		if on_change then
			on_change(self.value)
		end
		
		if (math.abs(self.speed) < self.min_speed) then
			self:stop()
		end
	end
end


function meta:input(action_id, action)
	if (action_id == vars.touch) then
		if (action.released) then
			if self.touched then
				self.touched = false
				if util.hit_node(self.clip_plane, action.screen_x, action.screen_y) then
					for key, val in pairs(self.nodes_on_screen) do
						if (util.hit_node(val[self.clone_name], action.screen_x, action.screen_y)) then
							print ('Scroll touched, key:', key)
							return { released = true, key = key}
						end
					end
				end
				print ('Scroll touched', self.moved)
				return { released = true}
			end
			return { }
		end
		
		if (self.touched) then
			if (math.abs(((self.vertical and action.screen_dy) or action.screen_dx)) > self.touch_speed_border) then
				self.moved = true
				self.speed = self.speed + ((self.vertical and action.screen_dy) or action.screen_dx) * self.touch_acceleration
				if (self.max_speed and math.abs(self.speed) > self.max_speed) then
					self.speed = self.max_speed * sign(self.speed)
				end
			end
		end
		
		if (action.pressed and util.hit_node(self.clip_plane, action.screen_x, action.screen_y)) then
			self.touched = true
			print ('Pressed on scroll')
			return { pressed = true }
		end
		
		return { touched = self.touched }
	end
end

function meta:get_node(i)
	return self.objects[i].clone
end

function meta:get_data(i)
	return self.objects[i].data
end

function meta:get_size()
	return #self.objects
end

function meta:get_value()
	return self.value
end

function meta:stop()
	self.moved = false
	self.speed = 0
end

function meta:get_moved()
	return self.moved
end


function meta:add_node(data, pos)
	local clone = gui.clone_tree(self.clone)
	
	self.bind(clone, data)
	gui.set_parent(clone[self.clone_name], self.objects_plane)
	gui.set_enabled(clone[self.clone_name], true)
	gui.set_position(clone[self.clone_name], get_node_position(self, pos))
	
	
	
	table.insert(self.objects, (pos or (#self.objects + 1)), {clone = clone, data = node })
	table.insert(self.nodes_on_screen, (pos or (#self.nodes_on_screen + 1)), clone)
	
	update_plane(self)
end

function meta:delete_node(i)
	for key, val in pairs(self.objects[i].clone) do
		gui.delete_node(val)
	end
	table.remove(self.objects, i)
	
	
	
	for key, val in ipairs(self.objects) do
		gui.set_position(val.clone[self.clone_name], get_node_position(self, key))
	end
	
	update_plane(self)
end


function meta:remove_all()
	for _, node in ipairs(self.objects) do
		for key, val in pairs(node.clone) do
			gui.delete_node(val)
		end
	end
	self.objects = { }
	
	update_plane(self)
end

return scope