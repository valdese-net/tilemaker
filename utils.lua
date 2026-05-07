function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

function ListContainsMatch(list,s)
	for _,s2 in pairs(list) do
		local m = string.find(s,s2)
		if m == 1 then return true end
	end
	return false
end

MajorRoadValues = Set { "motorway", "trunk", "primary" }
MainRoadValues  = Set { "secondary", "motorway_link", "trunk_link", "primary_link", "secondary_link" }
MidRoadValues   = Set { "tertiary", "tertiary_link" }
MinorRoadValues = Set { "unclassified", "residential", "road", "living_street" }
RoadsWithRef    = Set { "motorway", "primary" }
PathValues      = Set { "footway", "cycleway", "bridleway", "path", "steps", "pedestrian" }
PavedValues     = Set { "paved", "asphalt", "cobblestone", "concrete", "concrete:lanes", "concrete:plates", "metal", "paving_stones", "sett", "unhewn_cobblestone", "wood" }
ShowBuildings   = Set { "school", "public", "government", "fire_station", "industrial", "warehouse" }
ShowPlaceName   = Set { "town", "city", "municipality", "village", "hamlet" }
BRTATowns		= Set { "Glen Alpine", "Morganton", "Drexel", "Valdese", "Rutherford College", "Connelly Springs", "Rhodhiss", "Long View", "Hildebran" }

local replwords = {
	['North']='',['South']='',['East']='',['West']='',['Northeast']='',['Northwest']='',['Southeast']='',['Southwest']='',
	['Road']='Rd',['Avenue']='Ave',['Drive']='Dr',['Street']='St',['Boulevard']='Blvd',['Lane']='Ln',['Place']='Pl',['Extension']='Ext'
}
function DoPadStr(s) return (s:len() > 0) and ' '..s..' ' or ' ' end
function DoTrimRoadSuffixes(s)
	local s2 = s
	for k,v in pairs(replwords) do s2 = s2:gsub(' '..k..' ',DoPadStr(v)) end
	for k,v in pairs(replwords) do s2 = s2:gsub(k..'$',v) end
	s2 = s2:gsub("%s+$", "")
	for k,v in pairs(replwords) do s2 = s2:gsub(k..'$',v) end
	s2 = s2:gsub("%s+$", "")
	return s2
end

function GetFormattedRef()
	local ref = Find("ref")
	if ref~="" then return string.gsub(ref, ";", "\n") end
	return nil
end