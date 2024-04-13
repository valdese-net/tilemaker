--[[
	A simple tilemaker configuration.

	The basic principle is:
	- read OSM tags with Find(key)
	- write to vector tile layers with Layer(layer_name)
	- add attributes with Attribute(field, value)

	You can view your output with tilemaker-server:
	tilemaker-server /path/to/your.mbtiles --static server/static
]]--

-- Implement Sets in tables
function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

-- The height of one floor, in meters
BUILDING_FLOOR_HEIGHT = 3.66

majorRoadValues = Set { "motorway", "trunk", "primary" }
mainRoadValues  = Set { "secondary", "motorway_link", "trunk_link", "primary_link", "secondary_link" }
midRoadValues   = Set { "tertiary", "tertiary_link" }
minorRoadValues = Set { "unclassified", "residential", "road", "living_street" }
roadsWithRef    = Set { "motorway", "primary" }
trackValues     = Set { "track" }
pathValues      = Set { "footway", "cycleway", "bridleway", "path", "steps", "pedestrian" }
pavedValues     = Set { "paved", "asphalt", "cobblestone", "concrete", "concrete:lanes", "concrete:plates", "metal", "paving_stones", "sett", "unhewn_cobblestone", "wood" }
showBuildings   = Set { "school", "public", "government", "fire_station", "industrial", "warehouse" }
showPlaceName   = Set { "town", "city", "municipality" }

-- Process node tags
node_keys = { "place","tourism","waterway" }

-- Assign nodes to a layer, and set attributes, based on OSM tags
function node_function(node)
	local place  = Find("place")
	local name = getAsciiName()

	if showPlaceName[place] and name then
		Layer("label", false)
		Attribute("class", "place")
		Attribute("subclass", place)
		MinZoom(9)
		Attribute("name", name)
	end
end


-- Assign ways to a layer, and set attributes, based on OSM tags
function way_function()
	local highway  = Find("highway")
	local waterway = Find("waterway")
	local building = Find("building")
	local landuse  = Find("landuse")
	local leisure  = Find("leisure")

	if highway~="" and (Holds("name") or Holds("ref")) then
		local _,_,linked_path = highway:find("^(%l+)_link")
		if linked_path then
			highway = linked_path
		end
		if pathValues[highway] then
			highway = "path"
		end

		local objtype = "road"
		local objclass = highway

		if pathValues[highway] then
			objtype = "path"
		elseif trackValues[highway] then
			objtype = "path"
		end

		if objtype ~= "path" then
			Layer(objtype, false)
			--if highway=="unclassified" or highway=="residential" then highway="minor" end
			Attribute("class", objclass)
			if linked_path then AttributeNumeric("ramp",1) end

			local name = getAsciiName()
			if name then
				Attribute("name", name)
			end

			if roadsWithRef[objclass] and Holds("ref") and not linked_path then
				local ref = Find("ref")
				Attribute("ref", ref)
			end
		end			
	elseif Find("natural")=="water" then
		local c = (Find("water")=="river") and "river" or "lake"
		Layer("water", true)
		Attribute("class", c)
		local name = getAsciiName()
		if name then
			if (c == "lake") then
				LayerAsCentroid("label","centroid")
			else
				Layer("label", false)
			end
			
			Attribute("class", "water")
			Attribute("subclass", c)
			Attribute("name", name)
		end
	elseif waterway=="stream" or waterway=="river" or waterway=="canal" then
		Layer("waterway", false)
		if Find("intermittent")=="yes" then AttributeNumeric("intermittent", 1) else AttributeNumeric("intermittent", 0) end
		Attribute("class", waterway)
		local name = getAsciiName()
		if name then
			Attribute("name", name)
		end
	--elseif leisure=="park" and Holds("name") then
	--	Layer("park", true)
	--	Attribute("class", leisure)
	elseif showBuildings[building] then
		Layer("building", true)
		Attribute("class", building)
		SetBuildingHeightAttributes()
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

function SetBuildingHeightAttributes()
	local height = tonumber(Find("height"), 20)
	local minHeight = tonumber(Find("min_height"), 20)
	local levels = tonumber(Find("building:levels"), 10)
	local minLevel = tonumber(Find("building:min_level"), 10)

	local renderHeight = BUILDING_FLOOR_HEIGHT
	if height or levels then
		renderHeight = height or (levels * BUILDING_FLOOR_HEIGHT)
	end
	local renderMinHeight = 0
	if minHeight or minLevel then
		renderMinHeight = minHeight or (minLevel * BUILDING_FLOOR_HEIGHT)
	end

	-- Fix upside-down buildings
	if renderHeight < renderMinHeight then
		renderHeight = renderHeight + renderMinHeight
	end

	AttributeNumeric("render_height", renderHeight)
	AttributeNumeric("render_min_height", renderMinHeight)
end
