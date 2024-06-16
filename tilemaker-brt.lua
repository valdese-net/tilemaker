-- Implement Sets in tables
function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

majorRoadValues = Set { "motorway", "trunk", "primary" }
mainRoadValues  = Set { "secondary", "motorway_link", "trunk_link", "primary_link", "secondary_link" }
midRoadValues   = Set { "tertiary", "tertiary_link" }
minorRoadValues = Set { "unclassified", "residential", "road", "living_street" }
roadsWithRef    = Set { "motorway", "primary" }
trackValues     = Set { "track" }
pathValues      = Set { "footway", "cycleway", "bridleway", "path", "steps", "pedestrian" }
pavedValues     = Set { "paved", "asphalt", "cobblestone", "concrete", "concrete:lanes", "concrete:plates", "metal", "paving_stones", "sett", "unhewn_cobblestone", "wood" }

showBuildings   = Set { "school", "public", "government", "fire_station", "industrial", "warehouse" }

showPlaceName   = Set { "town", "city", "municipality", "village", "hamlet" }
brtMorphPlace = {["Longview"] = "Long View"}
brtPlaces = Set {"Glen Alpine","Morganton","Drexel","Valdese","Rutherford College","Connelly Springs","Rhodhiss","Long View","Hildebran"}

-- Process node tags
node_keys = { "place","tourism","waterway" }

-- Assign nodes to a layer, and set attributes, based on OSM tags
function node_function(node)
	local place  = Find("place")
	local name = getAsciiName()

	if brtMorphPlace[name] then name = brtMorphPlace[name] end

	if name and place and showPlaceName[place] and brtPlaces[name] then
		--print(place, name)
		Layer("label", false)
		Attribute("class", "place")
		Attribute("subclass", place)
		MinZoom(8)
		Attribute("name", name)
	--elseif name and name:match('Long') then -- brtPlaces[name]
	--	print('missed',name,place)
	end
end


-- Assign ways to a layer, and set attributes, based on OSM tags
function way_function()
	local addedLayer = false
	local waterway = Find("waterway")
	local highway  = Find("highway")
	local name = getAsciiName()

	if Holds("name") or Holds("ref") then
		if highway~="" then
			local _,_,linked_path = highway:find("^(%l+)_link")
			if linked_path then
				highway = linked_path
			end
			if pathValues[highway] then
				highway = "path"
			end
	
			local objtype = "road"
			local objclass = highway
	
			if majorRoadValues[highway] and not linked_path then
				addedLayer = true
				Layer("road", false)
				Attribute("class", highway)
			end
		elseif Find("natural")=="water" then
			local c = (Find("water")=="river") and "river" or "lake"
			addedLayer = true
			Layer("water", true)
			Attribute("class", c)
		elseif (waterway=="stream" or waterway=="river" or waterway=="canal") and (Find("intermittent")~="yes") then
			addedLayer = true
			Layer("waterway", false)
			Attribute("class", waterway)
			if (waterway~="river") or not name:find('River') then
				MinZoom(13)
			end
		end
		if addedLayer then
			if Holds("ref") then
				Attribute("ref", Find("ref"))
			end
			if name then
				Attribute("name", name)
			end
		end
	end
end

function isAscii(s)
	local i,j = s:find("[^%p%s%w]")
	return i == nil
end

local replwords = {
	['North']='',['South']='',['East']='',['West']='',['Northeast']='',['Northwest']='',['Southeast']='',['Southwest']='',
	['Road']='Rd',['Avenue']='Ave',['Drive']='Dr',['Street']='St',['Boulevard']='Blvd',['Lane']='Ln',['Extension']='Ext'
}
function padStr(s) return (s:len() > 0) and ' '..s..' ' or ' ' end
function trimSuffixes(s)
	local s2 = s
	for k,v in pairs(replwords) do s2 = s2:gsub(' '..k..' ',padStr(v)) end
	for k,v in pairs(replwords) do s2 = s2:gsub(k..'$',v) end
	s2 = s2:gsub("%s+$", "")
	for k,v in pairs(replwords) do s2 = s2:gsub(k..'$',v) end
	s2 = s2:gsub("%s+$", "")
	return s2
end

function getAsciiName()
	local name = Find("name")
	if name~="" and isAscii(name) then
		return trimSuffixes(name)
	end

	return nil
end
