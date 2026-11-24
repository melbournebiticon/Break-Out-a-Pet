--!strict
-- NumberFormat.luau
-- 1234 -> "1.2K", 3400000 -> "3.4M", 5600000000 -> "5.6B", 7.8e12 -> "7.8T", 9.1e15 -> "9.1Qa"
-- Max one decimal, no trailing ".0". Add more suffixes to the list to go higher.

local SUFFIXES: { string } = { "", "K", "M", "B", "T", "Qa" }

local NumberFormat = {}

function NumberFormat.Short(value: number): string
	if value ~= value then -- NaN guard
		return "0"
	end

	local sign = if value < 0 then "-" else ""
	local n = math.abs(value)

	if n < 1000 then
		return sign .. tostring(math.floor(n))
	end

	local index = 1
	while n >= 1000 and index < #SUFFIXES do
		n /= 1000
		index += 1
	end

	-- Round to one decimal
	local rounded = math.floor(n * 10 + 0.5) / 10

	-- Rounding can push 999.95K up to 1000.0K, so bump to the next suffix
	if rounded >= 1000 and index < #SUFFIXES then
		rounded /= 1000
		index += 1
	end

	local text = string.format("%.1f", rounded)
	text = (string.gsub(text, "%.0$", "")) -- remove trailing ".0"

	return sign .. text .. SUFFIXES[index]
end

return NumberFormat
