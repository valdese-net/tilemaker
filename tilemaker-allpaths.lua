require("utils")

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
BUILDING_FLOOR_HEIGHT = 4.5

TrackValues     = Set { "track", "service" }
ForceIncTowns	= Set { "Hickory", "Long View", "Rhodhiss" }
ManMades		= Set { "bridge", "pier" }
RailwayTypes	= Set { "rail", "light_rail", "subway", "tram" }
AerowayTypes 	= Set { "runway" }

function init_function(name)
	print(name, '<- init_function')
end

function attribute_function(attr,layer)
	if layer == 'citylimits' then
		return {county=attr['countyname'],name=attr['municipalb'],since=attr['year_incorporated']}
	end

	return attr
end

-- Process node tags
node_keys = { "place","tourism","waterway" }

-- Assign nodes to a layer, and set attributes, based on OSM tags
function node_function(node)
	local name = GetAsciiName()

	if not Intersects("burke") and not ForceIncTowns[name] and not Intersects("citylimits") then return end

	local place = Find("place")

	if ShowPlaceName[place] and name then
		Layer("label", false)
		Attribute("class", "place")
		if BRTATowns[name] then
			Attribute("subclass", "town")
			Attribute("brta", place)
		else
			Attribute("subclass", place)
		end
		MinZoom(9)
		Attribute("name", name)
	end
end


-- Assign ways to a layer, and set attributes, based on OSM tags
function way_function()
	local name = GetAsciiName()

	if not Intersects("burke") and not ForceIncTowns[name] and not Intersects("citylimits") then
		return
	end

	local railway  = Find("railway")
	local highway  = Find("highway")
	local aeroway  = Find("aeroway")
	local waterway = Find("waterway")
	local building = Find("building")
	local landuse  = Find("landuse")
	local leisure  = Find("leisure")
	local man_made = Find("man_made")
	local ref = GetFormattedRef()

--print("Way ID: ",Id(),name, railway, aeroway)

	if railway~="" then
		if not RailwayTypes[railway] then return end
		Layer("rail", false)
		Attribute("class", railway)
		return
	end

	if leisure=="park" then
		if not name then return end

		-- Parks and other leisure areas. Show the name as a label at the centroid of the polygon, and also show the park as a polygon with the name as an attribute for searchability.
		local minzoom = GetMinZoomByArea()

		Layer("park", true)
		Attribute("class", leisure)
		Attribute("name", name)
		MinZoom(minzoom)

		-- parks are usually a boundary area where LayerAsCentroid will end up correctly placing the label
		LayerAsCentroid("label","centroid")
		Attribute("class", "park")
		Attribute("subclass", leisure)
		MinZoom(11)
		Attribute("name", name)
		return
	end

	if ManMades[man_made] then
		Layer("manmade", true)
		Attribute("class", man_made)
		MinZoom(GetMinZoomByArea())
		return
	end

	-- Roads
	if highway~="" then
		local _,_,linked_path = highway:find("^(%l+)_link")
		if linked_path then
			highway = linked_path
		end
		if PathValues[highway] then
			highway = "path"
		end

		local minzoom = 99
		local objtype = "road"
		local objclass = highway

		if MajorRoadValues[highway] then minzoom = 4 end
		if highway == "trunk" then minzoom = 5
		elseif highway == "primary" then minzoom = 7 end
		if MainRoadValues[highway] then minzoom = 9 end
		if MidRoadValues[highway] then minzoom = 11 end
		if MinorRoadValues[highway] then minzoom = 13 end
		if PathValues[highway] then
			minzoom = 13
			objtype = "path"
		elseif TrackValues[highway] then
			minzoom = 13
			objtype = "path"
		end

		if minzoom <= 13 then
			Layer(objtype, false)
			--if highway=="unclassified" or highway=="residential" then highway="minor" end
			Attribute("class", objclass)
			MinZoom(minzoom)
			if linked_path then AttributeNumeric("ramp",1) end

			if ref then Attribute("ref", ref) end
			if name then Attribute("name", DoTrimRoadSuffixes(name) or name) end
		end
		return
	end

	if aeroway~="" then
		if not AerowayTypes[aeroway] then return end
		Layer("aero", false)
		if ref then Attribute("ref", ref) end
		if name then Attribute("name", name) end
		return
	end

	-- Lakes and other water polygons
	if Find("natural")=="water" then
		local c = Find("water") or "lake"
		local minzoom = GetMinZoomByArea()
		Layer("water", true)
		MinZoom(minzoom)
		Attribute("class", c)
		-- LayerAsCentroid can place the label outside of the polygon, so don't use it, just add the name as an attribute for searchability.
		if name then
			Attribute("name", name)
		end
		return
	end

	-- Rivers
	if (waterway=="stream" or waterway=="river" or waterway=="canal") and name and (Find("intermittent")~="yes") then
		Layer("waterway", false)
		Attribute("class", waterway)
		MinZoom(11)
		Attribute("name", name)
		return
	end

	-- Buildings
	--if ShowBuildings[building] then
	if building~="" then
		local housenum = Find("addr:housenumber")
		local amenity = Find("amenity")
		local shop = Find("shop")
		Layer("building", true)
		if building == "yes" then
			if amenity and amenity~="" then
				building = amenity
				amenity = nil
			elseif shop and shop~="" then
				building = shop
				shop = nil
			end
		end

		Attribute("class", building)
		if name then Attribute("name", name) end
		if housenum and housenum~="" then Attribute("num", housenum) end
		if amenity and amenity~="" then Attribute("amenity", amenity) end
		SetBuildingHeightAttributes()
		MinZoom(13)
		return
	end

end

function IsAscii(s)
	local i,j = s:find("[^%p%s%w]")
	return i == nil
end

function GetAsciiName()
	local name = Find("name")
	if name~="" and IsAscii(name) then
		return name
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

	if renderHeight > 5 then AttributeNumeric("height", renderHeight) end
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
	return 13
end
