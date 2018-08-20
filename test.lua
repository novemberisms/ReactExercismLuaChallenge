local react = require "react"
local tests = {}
local test_names = {}
local function test(name, fn)
	table.insert(test_names, name)
	table.insert(tests, fn)
end
--==========================================================
-- test callback
--==========================================================
local function new_test_callback()
	local callback = {}
	callback.times_called = 0
	callback.last_called_with = nil
	callback.fn = function(arg)
		callback.times_called = callback.times_called + 1
		callback.last_called_with = arg
	end
	return callback
end
--==========================================================
-- define tests
--==========================================================
test("input cells have a value", function()
	local r = react.Reactor()
	local input = r.InputCell(2)

	assert(input.get_value() == 2)
end)
--==========================================================
test("an input cell's value can be set", function()
	local r = react.Reactor()
	local input = r.InputCell(4)

	input.set_value(20)
	assert(input.get_value() == 20)
end)
--==========================================================
test("compute cells calculate initial value", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local output = r.ComputeCell(input, function(x) 
		return x + 1 
	end)

	assert(output.get_value() == 2)
end)
--==========================================================
test("compute cells take inputs in the right order", function()
	local r = react.Reactor()
	local one = r.InputCell(1)
	local two = r.InputCell(2)
	local output = r.ComputeCell(one, two, function(x, y) 
		return x + y * 10 
	end)

	assert(output.get_value() == 21)
end)
--==========================================================
test("compute cells update value when dependencies are changed", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local inc = r.InputCell(1)
	local output = r.ComputeCell(input, inc, function(x, y)
		return x + y
	end)

	input.set_value(3)
	assert(output.get_value() == 4)

	inc.set_value(2)
	assert(output.get_value() == 5)
end)
--==========================================================
test("compute cells can depend on other compute cells", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local times_two = r.ComputeCell(input, function(x)
		return x * 2
	end)
	local times_thirty = r.ComputeCell(input, function(x)
		return x * 30
	end)
	local output = r.ComputeCell(times_two, times_thirty, function(x, y)
		return x + y
	end)

	assert(output.get_value() == 32, "initial assertion")

	input.set_value(3)
	assert(output.get_value() == 96, "second assertion")

end)
--==========================================================
test("compute cells fire callbacks", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local output = r.ComputeCell(input, function(x) 
		return x + 1 
	end)

	local callback = new_test_callback()

	output.watch(callback.fn)
	input.set_value(3)
	assert(callback.times_called == 1)
	assert(callback.last_called_with == 4)
end)
--==========================================================
test("callbacks only fire on change", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local output = r.ComputeCell(input, function(x)
		if x < 3 then
			return 111
		else
			return 222
		end
	end)

	local callback = new_test_callback()

	output.watch(callback.fn)

	input.set_value(2)
	assert(callback.times_called == 0)

	input.set_value(4)
	assert(callback.times_called == 1)
	assert(callback.last_called_with == 222)
end)
--==========================================================
test("callbacks can be added and removed", function()
	local r = react.Reactor()
	local input = r.InputCell(11)
	local output = r.ComputeCell(input, function(x)
		return x + 1
	end)
	local callback1 = new_test_callback()
	local callback2 = new_test_callback()
	local callback3 = new_test_callback()

	output.watch(callback1.fn)
	output.watch(callback2.fn)
	input.set_value(31)

	output.unwatch(callback1.fn)
	output.watch(callback3.fn)
	input.set_value(41)

	assert(callback1.times_called == 1)
	assert(callback1.last_called_with == 32)
	assert(callback2.times_called == 2)
	assert(callback2.last_called_with == 42)
	assert(callback3.times_called == 1)
	assert(callback3.last_called_with == 42)

end)
--==========================================================
test("removing a callback multiple times doesn't interfere with other callbacks", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local output = r.ComputeCell(input, function(x)
		return x + 1
	end)
	local callback1 = new_test_callback()
	local callback2 = new_test_callback()

	output.watch(callback1.fn)
	output.watch(callback2.fn)

	for i = 1, 10 do output.unwatch(callback1.fn) end
	input.set_value(2)

	assert(callback1.times_called == 0)
	assert(callback2.times_called == 1)
	assert(callback2.last_called_with == 3)
end)

--==========================================================
test("callbacks only called once even if multiple inputs change", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local plus_one = r.ComputeCell(input, function(x)
		return x + 1
	end)
	local minus_one1 = r.ComputeCell(input, function(x)
		return x - 1
	end)
	local minus_one2 = r.ComputeCell(minus_one1, function(x)
		return x - 1
	end)
	local output = r.ComputeCell(plus_one, minus_one2, function(x, y)
		return x * y
	end)

	local callback = new_test_callback()
	output.watch(callback.fn)
	input.set_value(4)
	assert(callback.times_called == 1, "called more than once")
	assert(callback.last_called_with == 10, "called with wrong value")
end)

--==========================================================
test("callbacks not called if inputs change but output doesn't", function()
	local r = react.Reactor()
	local input = r.InputCell(1)
	local plus_one = r.ComputeCell(input, function(x)
		return x + 1
	end)
	local minus_one = r.ComputeCell(input, function(x)
		return x - 1
	end)
	local always_two = r.ComputeCell(plus_one, minus_one, function(x, y)
		return x - y
	end)
	local callback = new_test_callback()
	always_two.watch(callback.fn)

	for i = 1, 10 do input.set_value(i) end
	assert(callback.times_called == 0)

end)
--==========================================================
-- execute tests
--==========================================================
local successes = 0
local failures = 0
for i, test in ipairs(tests) do
	local res, err = pcall(test)
	if res then
		print("test "..i..": passed! ["..test_names[i].."]")
		successes = successes + 1
	else
		print("test "..i..": FAILED! ["..test_names[i].."] "..err)
		failures = failures + 1
	end
end
print("")
print("TESTS PASSED: "..successes)
print("TESTS FAILED: "..failures)