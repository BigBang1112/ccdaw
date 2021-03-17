function table_merge(first_table, second_table)
	for k,v in pairs(second_table) do
		first_table[k] = v
	end
end

function table_count(table)
	if table == nil then
		return 0
	end

	local count = 0
	for _ in pairs(table) do
		count = count + 1
	end
	return count
end

function clamp(num, min, max)
	if num < min then
		num = min
	elseif num > max then
		num = max    
	end
	
	return num
end

function round2(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
end

function format_second_time(seconds)
	local s = tonumber(seconds)
	
	if s % 60 < 10 then
		return textutils.formatTime(s/3600, true) .. ":0" .. string.format("%.2f", round2(s % 60, 2))
	else
		return textutils.formatTime(s/3600, true) .. ":" .. string.format("%.2f", round2(s % 60, 2))
	end
end

function split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end