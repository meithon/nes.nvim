local new_set = MiniTest.new_set
local eq = MiniTest.expect.equality

local T = new_set()

T.core = new_set()

T.core.hello = function()
	eq(1, 1)
end

return T
