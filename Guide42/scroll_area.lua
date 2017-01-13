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
	return (x >= min and x <= max)
end

local function is_node_on_screen(self, pos)
	if (self.vertical) then
		local left, right = pos - self.object_size.y / 2 + self.position.y, pos + self.object_size.y / 2 + self.position.y
		local temp = gui.get_size(self.clip_plane)
		return is_entry(left, -temp.y / 2, temp.y / 2) or is_entry(right, -temp.y / 2, temp.y / 2)
	else 
		local left, right = pos - self.object_size.x / 2 + self.position.x, pos + self.object_size.x / 2 + self.position.x
		local temp = gui.get_size(self.clip_plane)
		return is_entry(left, -temp.x / 2, temp.x / 2) or is_entry(right, -temp.x / 2, temp.x / 2) 
	end
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
		self.value = 1 + (math.abs(self.position.y) - self.object_size.y * 0.5 - self.padding_vertical) / (self.object_size.y + self.between)
	else	
		self.value = 1 + (math.abs(self.position.x) - self.object_size.x * 0.5 - self.padding_horizontal) / (self.object_size.x + self.between)
	end
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


local function get_clone_node(self)
	local clone
	if (#self.nodes == 0) then
		clone = gui.clone_tree(self.clone)
		gui.set_parent(clone[self.clone_name], self.objects_plane)
	else
		clone = table.remove(self.nodes)
	end
	gui.set_enabled(clone[self.clone_name], true)
	return clone
end

local function add_clone_node(self, clone)
	gui.set_enabled(clone[self.clone_name], false)
	table.insert(self.nodes, clone)
end

local function update_node(self, i)
	local pos = get_node_position(self, i)
	if (self.vertical) then
		pos = pos.y
	else
		pos = pos.x
	end
	
	if is_node_on_screen(self, pos) then
		if (self.objects[i].clone == nil) then
			self.objects[i].clone = get_clone_node(self)
			gui.set_position(self.objects[i].clone[self.clone_name], get_node_position(self, i))
			self.bind(self.objects[i].clone, self.objects[i].data)

		end
	else
		if (self.objects[i].clone ~= nil) then
			add_clone_node(self, self.objects[i].clone)
			self.objects[i].clone = nil
		else
			return true
		end
	end
end

local function update_nodes_visiable(self)
	if (#self.objects == 0) then
		return
	end
	
	local i = math.floor(self.value) - 1
	
	while (i > 0) do
		if (update_node(self, i)) then
			break
		end
		i = i - 1
	end
	
	i = math.floor(self.value)
	while (i <= #self.objects) do
		if (update_node(self, i)) then
			break
		end
		i = i + 1
	end
end


local function update_plane(self)
	set_plane_size(self)
	if (not set_plane_position(self)) then
		self:stop()
	end
	set_value(self)
	update_nodes_visiable(self)
end



function scope.init(id, settings)
	local obj = { 
		clip_plane = util.safe_get_node(id..'/clip_plane'),
		objects_plane = util.safe_get_node(id..'/objects_plane'),
		
		
		clone = util.safe_get_node(settings.clone_name),
		
		
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
		clone_name = settings.clone_name or "guide42_scroll",
		bind = settings.bind
		
	}
	
	
	
	obj.object_size = gui.get_size(obj.clone),
	gui.set_enabled(obj.clone, false)
	
	
	if (obj.vertical) then
		gui.set_pivot(obj.objects_plane, gui.PIVOT_S)
		local temp = gui.get_size(obj.clip_plane)
		gui.set_size(obj.clip_plane, vmath.vector3(obj.object_size.x + 2 * obj.padding_horizontal, temp.y, 0))
		temp = gui.get_size(obj.objects_plane)
		gui.set_size(obj.objects_plane, vmath.vector3(obj.object_size.x + 2 * obj.padding_horizontal, temp.y, 0))
	else
		gui.set_pivot(obj.objects_plane, gui.PIVOT_W)
		local temp = gui.get_size(obj.clip_plane)
		gui.set_size(obj.clip_plane, vmath.vector3(temp.x, obj.object_size.y + 2 * obj.padding_vertical, 0))
		temp = gui.get_size(obj.objects_plane)
		gui.set_size(obj.objects_plane, vmath.vector3(temp.x, obj.object_size.y + 2 * obj.padding_vertical, 0))
	end
	
	local temp = gui.get_position(obj.objects_plane)
	temp.x = 0
	temp.y = 0
	obj.position = temp
	gui.set_position(obj.objects_plane, temp) 
	
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
		
		if (not set_plane_position(self)) then
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
		
		update_nodes_visiable(self)
	end
end


function meta:input(action_id, action)
	if (action_id == vars.touch) then
		if (action.released) then
			if self.touched then
				self.touched = false
				if util.hit_node(self.clip_plane, action.x, action.y) then
					for key, val in pairs(self.objects) do
						if (val.clone and util.hit_node(val.clone[self.clone_name], action.x, action.y)) then
							return { released = true, touched = true, key = key}
						end
					end
				end
				return { released = true, touched = true}
			end
			return { touched = false }
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
			return { pressed = true, touched = true }
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
	
	table.insert(self.objects, (pos or (#self.objects + 1)), {clone = clone, data = data })
	
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
	self.nodes = { }
	
	update_plane(self)
end

return scope