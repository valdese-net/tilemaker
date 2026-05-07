-- Implement Sets in tables
function Set(list)
	local set = {}
	for _, l in ipairs(list) do set[l] = true end
	return set
end

function node_function(node)
	local centroids  = Find("centroids")
	if centroids then
		local name = Find("NAME")
		local abbrev = Find("ABBREV")
		Layer("centroids", false)
		Attribute("name", name)
		Attribute("nm", abbrev)
	end
end

function way_function()
	local geolines  = Find("geolines")
	local countries = Find("countries")

	if geolines then
		local name = Find("name")
		Layer("geolines", false)
		Attribute("name", name)
		return
	end

	if countries then
		local id = Find("ADM0_A3")
		local name = Find("NAME")
		local continent = Find("CONTINENT")
		Layer("countries", true)
		Attribute("id", id)
		Attribute("name", name)
		Attribute("continent", continent)
		return
	end
end

function IsAscii(s)
	local i,j = s:find("[^%p%s%w]")
	return i == nil
end
