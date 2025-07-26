#!/usr/bin/lua5.3
--Requires Lua5.3 or newer
--Generates the expected forms of piece shapes
--Quit inefficient but runs only once :)

--Each line of a shape description should be of the same length, so don't remove trailing whitespaces
local shapestring = [[
I_piece:
####
L_piece:
  #
###
J_piece:
#  
###
S_piece:
 ##
## 
Z_piece:
## 
 ##
T_piece:
 # 
###
O_piece:
##
##
]]

local function getbase2(t)
	local s = ""
	local ysz, xsz = #t, #t[1]

	--reposition piece to the middle
	local ybegin, xbegin = 1 + (4 - ysz) // 2, 1 + (4 - xsz) // 2
	local yend, xend = ysz + ybegin - 1, xsz + xbegin - 1

	for y = 1, 4 do
		if y < ybegin or y > yend then
			s = "0000" .. s
		else
			for x = 1, 4 do
				if x < xbegin or x > xend then
					s = "0" .. s
				elseif t[y - ybegin + 1][x - xbegin + 1] then
					s = "1" .. s
				else
					s = "0" .. s
				end
			end
		end
	end

	return "0b" .. s
end

local function rotate(t)
	--x, y sizes of old shape
	local ysz, xsz = #t, #t[1]
	local newt = {}

	for y = 1, xsz do
		local row = {}
		newt[y] = row
		for x = 1, ysz do
			row[x] = t[ysz+1-x][y]
		end
	end

	return newt
end

io.write("; auto-generated with ./gen_shapes.lua\n")
io.write("; ", string.rep(" ", 14))
for i = 1, 4 do
	io.write(string.format("    rotation %d", i))
	if i ~= 4 then io.write("    ", "  ") end
end

io.write("\n; ", string.rep(" ", 14))
for i = 1, 4 do
	io.write(string.rep("=", 18))
	if i ~= 4 then io.write("  ") end
end
io.write("\n")

for name, description in shapestring:gmatch("([%w_]+):\n([ #\n]+)") do
	local t = {}
	for line in description:gmatch("([# ]+)") do
		local row = {}
		table.insert(t, row)
		for i = 1, #line do
			row[i] = line:sub(i, i) == "#"
		end
	end

	local str = name .. ":" .. string.rep(" ", 11 - #name) .. " dw "
	io.write(str)
	for i = 1, 4 do
		io.write(getbase2(t))

		if i == 4 then break end
		io.write(", ")
		t = rotate(t)
	end
	io.write("\n")
end
