local React = {}
--==========================================================
-- InputCell
--==========================================================
local function newInputCell(initial_value)
	local self = {}
	----------------------------------------------------------
	self.value = initial_value
	self.children = {}
	----------------------------------------------------------
	-- just a simple wrapper. people can use self.value directly
	-- if they want to
	self.get_value = function()
		return self.value
	end
	----------------------------------------------------------
	-- doesn't do anything if no change
	-- triggers a chain reaction down the tree
	-- where each child will update based on the parent's new value
	self.set_value = function(value)
		if value == self.value then return end
		self.value = value
		self.propagate_value_change()
	end
	----------------------------------------------------------
	-- it ensures that each cell in the tree is updated once and only once
	-- it does this with a recursive depth probe and then it updates the tree
	-- one level of depth at a time
	self.propagate_value_change = function()
		-- this is a dict whose keys are the cells themselves
		-- and the value is their depth
		-- there is also a special "max_depth" key that tells us
		-- the deepest depth value reached
		local depth_lookup = {
			max_depth = 0
		}
		-- first, run through the tree and assign depth order
		self.recursive_assign_depth(self, 0, depth_lookup)
		-- now, for each depth at a time, update the values of the cells
		for current_depth = 1, depth_lookup.max_depth do
			for cell, depth in pairs(depth_lookup) do
				-- we check if cell is a table so we don't try to call update on "max_depth"
				if type(cell) == "table" and depth == current_depth then
					cell.update()
				end
			end
		end
	end
	----------------------------------------------------------
	self.recursive_assign_depth = function(cell, depth, depth_lookup)
		-- assign depth in depth lookup table
		-- new entry
		if not depth_lookup[cell] then 
			depth_lookup[cell] = depth
		-- already existing, but we're assigning it a higher depth.
		-- if a cell depends on two other cells, then its depth
		-- is the depth of the deeper cell + 1
		elseif depth_lookup[cell] and depth > depth_lookup[cell] then
			depth_lookup[cell] = depth
		end
		-- update the max_depth
		if depth > depth_lookup.max_depth then 
			depth_lookup.max_depth = depth
		end
		-- recursively go through children of cell
		for _, child in ipairs(cell.children) do
			self.recursive_assign_depth(child, depth + 1, depth_lookup)
		end
	end
	----------------------------------------------------------
	return self
end
--==========================================================
-- ComputeCell
--==========================================================
-- supports more than 2 inputs at a time, as many as needed
-- as long as the last argument is the computation callback
local function newComputeCell(...)
	local self = {}
	local args = {...}
	----------------------------------------------------------
	self.value = nil -- this is updated later on. you can omit this line, but I left it in for clarity
	self.children = {}
	self.callbacks = {}
	----------------------------------------------------------
	-- the computation is always the last argument
	self.computation = table.remove(args) 
	-- args is now an array of the input cells
	self.inputs = args
	for _, cell in ipairs(self.inputs) do
		table.insert(cell.children, self)
	end
	----------------------------------------------------------
	-- same deal as in newInputCell
	self.get_value = function()
		return self.value
	end
	----------------------------------------------------------
	self.calculate_value = function()
		local inputs = {}
		-- collect the values of all inputs
		for _, cell in ipairs(self.inputs) do
			table.insert(inputs, cell.get_value())
		end
		return self.computation(unpack(inputs))
	end
	----------------------------------------------------------
	self.update = function()
		local new_value = self.calculate_value()
		if new_value == self.value then return end
		self.value = new_value
		for _, callback in ipairs(self.callbacks) do
			callback(self.value)
		end
	end
	----------------------------------------------------------
	self.watch = function(callback)
		-- ignore if you're trying to add the same callback twice
		for _, existing in ipairs(self.callbacks) do
			if existing == callback then return end
		end
		table.insert(self.callbacks, callback)
	end
	----------------------------------------------------------
	self.unwatch = function(callback)
		for i, existing in ipairs(self.callbacks) do
			if existing == callback then
				return table.remove(self.callbacks, i)
			end
		end
	end
	----------------------------------------------------------
	self.update()
	return self
end
--==========================================================
-- Reactor
--==========================================================
function React.Reactor()
	local self = {}
	----------------------------------------------------------
	self.InputCell = newInputCell
	----------------------------------------------------------
	self.ComputeCell = newComputeCell
	----------------------------------------------------------
	return self
end
--==========================================================
return React