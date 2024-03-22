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

-- Meters per pixel if tile is 256x256
ZRES5  = 4891.97
ZRES6  = 2445.98
ZRES7  = 1222.99
ZRES8  = 611.5
ZRES9  = 305.7
ZRES10 = 152.9
ZRES11 = 76.4
ZRES12 = 38.2
ZRES13 = 19.1

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

	if showPlaceName[place] and Holds("name") then
		Layer("label", false)
		Attribute("class", "place")
		Attribute("subclass", place)
		MinZoom(9)
		SetNameAttribute()
	end
end


-- Assign ways to a layer, and set attributes, based on OSM tags
function way_function()
	local highway  = Find("highway")
	local waterway = Find("waterway")
	local building = Find("building")
	local landuse  = Find("landuse")
	local leisure  = Find("leisure")

	if leisure=="park" and Holds("name") then
		Layer("park", true)
		Attribute("class", leisure)
		MinZoom(GetMinZoomByArea())
	end

	-- Roads
	if highway~="" then
		local _,_,linked_path = highway:find("^(%l+)_link")
		if linked_path then
			highway = linked_path
		end
		if pathValues[highway] then
			highway = "path"
		end

		local minzoom = 99
		local objtype = "road"
		local objclass = highway

		if majorRoadValues[highway] then minzoom = 4 end
		if highway == "trunk" then minzoom = 5
		elseif highway == "primary" then minzoom = 7 end
		if mainRoadValues[highway] then minzoom = 9 end
		if midRoadValues[highway] then minzoom = 11 end
		if minorRoadValues[highway] then minzoom = 12 end
		if pathValues[highway] then
			minzoom = 14
			objtype = "path"
		elseif trackValues[highway] then
			minzoom = 14
			objtype = "path"
		end

		if minzoom <= 14 then
			Layer(objtype, false)
			--if highway=="unclassified" or highway=="residential" then highway="minor" end
			Attribute("class", objclass)
			MinZoom(minzoom)
			if linked_path then AttributeNumeric("ramp",1) end

			if Holds("name") then
				Layer("label", false)
				Attribute("class", objtype)
				Attribute("subclass", objclass)
				MinZoom(math.min(minzoom+1,14))
				SetNameAttribute()
			end

			if roadsWithRef[objclass] and Holds("ref") and not linked_path then
				local ref = Find("ref")
				Layer("label", false)
				Attribute("ref", ref)
				Attribute("class", "shield")
				Attribute("subclass", objclass)
				MinZoom(13)
			end
		end
	end

	-- Lakes and other water polygons
	if Find("natural")=="water" then
		local c = (Find("water")=="river") and "river" or "lake"
		Layer("water", true)
		local minzoom = GetMinZoomByArea()
		MinZoom(minzoom)
		Attribute("class", c)
		if Holds("name") then
			if (c == "lake") then
				LayerAsCentroid("label","centroid")
			else
				Layer("label", false)
			end
			
			Attribute("class", "water")
			Attribute("subclass", c)
			MinZoom(minzoom)
			SetNameAttribute()
		end
	end

	-- Rivers
	if waterway=="stream" or waterway=="river" or waterway=="canal" then
		Layer("waterway", false)
		if Find("intermittent")=="yes" then AttributeNumeric("intermittent", 1) else AttributeNumeric("intermittent", 0) end
		Attribute("class", waterway)
		MinZoom(11)
		if Holds("name") then
			Layer("label", false)
			Attribute("class", "waterway")
			Attribute("subclass", waterway)
			MinZoom(13)
			SetNameAttribute()
		end
	end

	-- Buildings
	if showBuildings[building] then
		Layer("building", true)
		Attribute("class", building)
		SetBuildingHeightAttributes()
		MinZoom(GetMinZoomByArea())
	end

end

-- Set name attributes on any object
function SetNameAttribute()
	local name = Find("name")
	if name~="" then
		Attribute("name:latin", name)
	end
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

-- Set minimum zoom level by area
function GetMinZoomByArea()
	local area=Area()
	if area>ZRES5^2  then return 6 end
	if area>ZRES6^2  then return 7 end
	if area>ZRES7^2  then return 8 end
	if area>ZRES8^2  then return 9 end
	if area>ZRES9^2  then return 10 end
	if area>ZRES10^2 then return 11 end
	if area>ZRES11^2 then return 12 end
	if area>ZRES12^2 then return 13 end
	return 14
end
