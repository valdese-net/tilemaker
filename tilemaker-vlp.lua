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

function listContainsMatch(list,s)
	for _,s2 in pairs(list) do
		local m = string.find(s,s2)
		if m == 1 then return true end
	end
	return false
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
showPlaceName   = Set { "town", "city", "municipality", "village", "hamlet" }
showWaterTypes	= Set { "lake", "river" }
burkePlaces		= Set { "Glen Alpine","Morganton","Drexel","Valdese","Rutherford College","Connelly Springs","Rhodhiss","Long View","Hildebran" }
showWaterways	= Set { "stream", "river", "canal" }
forceRoads		= {"Malcolm B","Rutherford College","Eldred St","Laurel St","Church St","Carolina St"}


-- Process node tags
node_keys = { "place","tourism","waterway" }

function attribute_function(attr,layer)
	if layer == 'citylimits' then
		return {county=attr['countyname'],name=attr['municipalb'],since=attr['year_incorporated']}
	end

	return attr
end

-- Assign nodes to a layer, and set attributes, based on OSM tags
function node_function(node)
	local place  = Find("place")
	local name = getAsciiName()

	if showPlaceName[place] and burkePlaces[name] then
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
	local name = getAsciiName()
	local vlp_areas = Set(FindIntersecting("vlp-area"))
	local closetoVLP = vlp_areas["vlp-area"]

	if highway~="" and Holds("ref") then
		name = Find("ref")
	end

	if not Intersects("burke") then return end

	if highway~="" and (name or Holds("ref")) then
		local _,_,linked_path = highway:find("^(%l+)_link")
		if linked_path then
			highway = linked_path
		end
		if pathValues[highway] then
			highway = "path"
		end

		local objtype = "road"
		local objclass = highway

		if pathValues[highway] or trackValues[highway] then return end
		if not closetoVLP and not majorRoadValues[highway] then
			if not name or not listContainsMatch(forceRoads,name) then return end
		end

		Layer(objtype, false)
		--if highway=="unclassified" or highway=="residential" then highway="minor" end
		Attribute("class", objclass)
		if linked_path then AttributeNumeric("ramp",1) end

		if not majorRoadValues[objclass] then
			MinZoom(12)
		end
		if name then Attribute("name", name) end
	elseif (Find("natural")=="water") then
		if not vlp_areas["water-area"] then return end
		local c = Find("water")
		Layer("water", true)
		if c ~= "" then Attribute("class", c) end
	elseif showWaterways[waterway] then
		if not vlp_areas["water-area"] then return end
		Layer("waterway", false)
		if Find("intermittent")=="yes" then AttributeNumeric("intermittent", 1) else AttributeNumeric("intermittent", 0) end
		Attribute("class", waterway)
		if name then Attribute("name", name) end
	elseif showBuildings[building] then
		if not closetoVLP then return end

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
