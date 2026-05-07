require("utils")

--[[
	A simple tilemaker configuration.

	The basic principle is:
	- read OSM tags with Find(key)
	- write to vector tile layers with Layer(layer_name)
	- add attributes with Attribute(field, value)

	You can view your output with tilemaker-server:
	tilemaker-server /path/to/your.mbtiles --static server/static
]]--

-- The height of one floor, in meters
BUILDING_FLOOR_HEIGHT = 3.66

TrackValues     = Set { "track" }
ShowWaterTypes	= Set { "lake", "river" }
BurkePlaces		= Set { "Glen Alpine","Morganton","Drexel","Valdese","Rutherford College","Connelly Springs","Rhodhiss","Long View","Hildebran" }
ShowWaterways	= Set { "stream", "river", "canal" }
ForceRoads		= {"Malcolm B","Rutherford College","Eldred St","Laurel St","Church St","Carolina St"}


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
	local name = GetAsciiName()

	if ShowPlaceName[place] and BurkePlaces[name] then
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
	local name = GetAsciiName()
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
		if PathValues[highway] then
			highway = "path"
		end

		local objtype = "road"
		local objclass = highway

		if PathValues[highway] or TrackValues[highway] then return end
		if not closetoVLP and not MajorRoadValues[highway] then
			if not name or not ListContainsMatch(ForceRoads,name) then return end
		end

		Layer(objtype, false)
		--if highway=="unclassified" or highway=="residential" then highway="minor" end
		Attribute("class", objclass)
		if linked_path then AttributeNumeric("ramp",1) end

		if not MajorRoadValues[objclass] then
			MinZoom(12)
		end
		if name then Attribute("name", name) end
	elseif (Find("natural")=="water") then
		if not vlp_areas["water-area"] then return end
		local c = Find("water")
		Layer("water", true)
		if c ~= "" then Attribute("class", c) end
	elseif ShowWaterways[waterway] then
		if not vlp_areas["water-area"] then return end
		Layer("waterway", false)
		if Find("intermittent")=="yes" then AttributeNumeric("intermittent", 1) else AttributeNumeric("intermittent", 0) end
		Attribute("class", waterway)
		if name then Attribute("name", name) end
	elseif ShowBuildings[building] then
		if not closetoVLP then return end

		Layer("building", true)
		Attribute("class", building)
		SetBuildingHeightAttributes()
	end
end

function IsAscii(s)
	local i,j = s:find("[^%p%s%w]")
	return i == nil
end

function GetAsciiName()
	local name = Find("name")
	if name~="" and IsAscii(name) then
		return DoTrimRoadSuffixes(name)
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
