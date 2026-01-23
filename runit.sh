#!/bin/bash
mkdir -p data

# fetch the latest for North Carolina https://download.geofabrik.de/north-america/us/north-carolina-latest.osm.pbf
wget https://download.geofabrik.de/north-america/us/north-carolina-latest.osm.pbf -q --show-progress -N -P ./data

# alternatively, use https://download.geofabrik.de/north-america/us-south.html
wget https://download.geofabrik.de/north-america/us-south-latest.osm.pbf -q --show-progress -N -P ./data


# terrain USGS 1/3 Arc Second
# https://github.com/nst-guide/terrain
# wget https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/historical/n36w082/USGS_13_n36w082_20220512.tif  -q --show-progress -N -P ./data

# extract Burke and Valdese areas
# prereq: sudo apt install osmctools
# --complex-ways --strategy=smart yielded fragments
# --complete-ways --complete-multipolygons --complete-boundaries
osmconvert data/north-carolina-latest.osm.pbf -b=-82,35.55,-81.35,36.01 --complete-boundaries -o=data/burke.osm.pbf
osmconvert data/north-carolina-latest.osm.pbf -b=-81.623,35.725,-81.523,35.790 --complete-boundaries -o=data/valdese.osm.pbf
# alternate: -81.57286,35.75574 -81.53452,35.77947
osmconvert data/north-carolina-latest.osm.pbf -b=-81.5781,35.7619,-81.5293,35.7883 --complete-boundaries -o=data/vlp.osm.pbf

tilemaker data/north-carolina-latest.osm.pbf --output=data/nc.pmtiles --config tilemaker-allpaths.json --process tilemaker-allpaths.lua
tilemaker data/north-carolina-latest.osm.pbf --output=data/burke.pmtiles --config tilemaker-allpaths.json --process tilemaker-allpaths.lua
tilemaker data/valdese.osm.pbf --output=data/valdese.pmtiles --config tilemaker-allpaths.json --process tilemaker-allpaths.lua
tilemaker data/vlp.osm.pbf --output=data/vlp.pmtiles --config tilemaker-allpaths.json --process tilemaker-allpaths.lua

# valdese-area generated via https://app.protomaps.com/
tilemaker data/valdese-area.osm.pbf --output=data/valdese-area.pmtiles --config tilemaker-vlp.json --process tilemaker-vlp.lua

# burke-river-trail (brt) map
tilemaker data/north-carolina-latest.osm.pbf --output=data/brt_v2.pmtiles --config tilemaker-brt.json --process tilemaker-brt.lua
tilemaker data/north-carolina-latest.osm.pbf --output=data/vlp.pmtiles --config tilemaker-vlp.json --process tilemaker-vlp.lua

#pmtiles convert valdese.mbtiles valdese.pmtiles
#pmtiles convert burke.mbtiles burke.pmtiles

ogrinfo -so data/parcels nc_burke_parcels_poly

# convert shape file with Lambert_Conformal_Conic projection to geojson
# -lco STRING_QUOTING=IF_NEEDED
ogr2ogr -f GeoJSON -s_srs data/parcels/nc_burke_parcels_poly.prj -t_srs EPSG:4326 data/parcels.geojson data/parcels/nc_burke_parcels_poly.shp
ogr2ogr -f GeoJSON -s_srs data/counties/cb_2023_us_county_500k.prj -t_srs EPSG:4326 data/counties.geojson data/counties/cb_2023_us_county_500k.shp
ogr2ogr -f GeoJSON -s_srs data/states/cb_2023_us_state_500k.prj -t_srs EPSG:4326 data/us-states.geojson data/states/cb_2023_us_state_500k.shp

# using burke.gdb from https://www.burkenc.org/2495/Data-Sets
ogrinfo -so data/burke_20250624.gdb.zip SiteStructureAddressPoints
ogrinfo -json -where "CITYLIM LIKE '%'" data/burke_20250624.gdb.zip SiteStructureAddressPoints | more
ogrinfo -where "ADDRESS=''" data/burke_20250624.gdb.zip SiteStructureAddressPoints | more
#ogr2ogr -f GeoJSON -t_srs EPSG:4326 -select "STNUM,PREDIR,STREET_NAM,TYPE,POSTDIR,UNITTYPE,UNIT,CITY,ZIPCODE,PIN,CITYLIM,ETJ" data/burke-addresses.geojson data/burke_20250624.gdb.zip SiteStructureAddressPoints
ogr2ogr -f CSV -lco GEOMETRY=AS_XY -select "STNUM,PREDIR,STREET_NAM,TYPE,POSTDIR,UNITTYPE,UNIT,CITY,ZIPCODE,PIN,CITYLIM,ETJ" -t_srs EPSG:4326 data/burke-addresses.csv data/burke_20250624.gdb.zip SiteStructureAddressPoints
ogrinfo -so data/burke_20250624.gdb.zip RoadCenterlines

ogrinfo -so data/burke_20250624.gdb.zip PROD_PARCEL_VIEW_FC | grep 'Geometry Column'
ogr2ogr -f CSV -sql "SELECT PIN,PROPERTY_OWNER,LOCATION_ADDR,ETJ,TOTAL_PROP_VALUE FROM PROD_PARCEL_VIEW_FC WHERE PIN LIKE '%' AND PROPERTY_OWNER LIKE '%'" data/owners.csv data/burke_20250624.gdb.zip
ogr2ogr -f GeoJSON -sql "SELECT PIN,Shape FROM PROD_PARCEL_VIEW_FC" -t_srs EPSG:4326 data/burke-parcels2.geojson data/burke_20250624.gdb.zip
#
# just a point for each parcel
ogr2ogr -f GeoJSON -sql "SELECT ST_PointOnSurface(Shape), * FROM PROD_PARCEL_VIEW_FC" -dialect sqlite -t_srs EPSG:4326 data/parcelpts.geojson data/burke_20250624.gdb.zip
ogr2ogr -f CSV  -lco GEOMETRY=AS_XY -sql "SELECT REID,PIN,PIN_EXT,ST_PointOnSurface(Shape) FROM PROD_PARCEL_VIEW_FC" -dialect sqlite -t_srs EPSG:4326 data/parcelpts.csv data/burke_20250624.gdb.zip
#
ogr2ogr -f GeoJSON -where "PIN LIKE '%'" -t_srs EPSG:4326 -select "REID,PIN,PIN_EXT,LOCATION_ADDR,PHYADDR_CITY,PHYADDR_ZIP" data/burke-parcels.geojson data/burke_20250624.gdb.zip PROD_PARCEL_VIEW_FC
ogr2ogr -f GeoJSON -t_srs EPSG:4326 -select "SRNUM,CLASS,FULLNAME" data/burke-roads.geojson data/burke_20250624.gdb.zip RoadCenterlines
ogr2ogr -f GeoJSON -t_srs EPSG:4326 data/burke-city-limits.geojson data/burke_20250624.gdb.zip city_limits

php filter-duplicate-pins.php <  data/burke-parcels.geojson > data/burke-parcels2.geojson
mv -f data/burke-parcels2.geojson data/burke-parcels.geojson
rm data/burke-map.pmtiles
tippecanoe -Z6 -z16 --coalesce-densest-as-needed --simplify-only-low-zooms -f -o data/burke-map.pmtiles \
	--named-layer='nc:data/nc-boundary.geojson' --named-layer='burke:data/burke-boundary.geojson' \
	--named-layer='citynames:burke-city-names.json' --named-layer='city:data/burke-city-limits.geojson' \
	--named-layer='parcels:data/burke-parcels.geojson' --named-layer='roads:data/burke-roads.geojson'

# create parcel tiles to a precision of 6 inches
tippecanoe -f -o data/valdese-parcels.pmtiles -l vparcels -n "Valdese Parcels" -Z10 -z16 data/valdese-parcels.geojson
tippecanoe -f -o data/burke-parcels.pmtiles -l parcels -n "Burke  Parcels" -Z6 -z16 data/parcels.geojson

#
# All Data
ogr2ogr -f GeoJSON -t_srs EPSG:4326 data/burke-parcels-alldata.geojson data/burke_20250624.gdb.zip PROD_PARCEL_VIEW_FC
ogr2ogr -f GeoJSON -t_srs EPSG:4326 data/burke-addresses-alldata.geojson data/burke_20250624.gdb.zip SiteStructureAddressPoints
tippecanoe -Z6 -z16 --coalesce-densest-as-needed --simplify-only-low-zooms -f -o data/burke-map-alldata.pmtiles \
	--named-layer='nc:data/nc-boundary.geojson' --named-layer='burke:data/burke-boundary.geojson' \
	--named-layer='citynames:burke-city-names.json' --named-layer='city:data/burke-city-limits.geojson' \
	--named-layer='parcels:data/burke-parcels-alldata.geojson' --named-layer='addresses:data/burke-addresses-alldata.geojson' --named-layer='roads:data/burke-roads.geojson'

#
# New Owners
ogr2ogr -f CSV -sql "SELECT DEED_DATE,PROPERTY_OWNER,PHYADDR_STR_NUM,PHYADDR_DIR_PFX,PHYADDR_STR,PHYADDR_STR_TYPE FROM PROD_PARCEL_VIEW_FC WHERE (ETJ LIKE 'VALDESE')" data/burke-newowners.csv data/burke_20250624.gdb.zip

# extract park parcels
node extract-parcels-by-parno.js data/parcels.geojson valdese-parcels.txt > data/vlp-parcels.geojson
node extract-parcels-by-parno.js data/parcels.geojson brt-parcels-private.txt > data/brt-parcels-private.geojson
node extract-parcels-by-parno.js data/parcels.geojson brt-parcels-public.txt > data/brt-parcels-public.geojson

gdal_translate -of GTiff -co "TILED=YES" data/dem/burke-DEM03.tif data/burke-tiled.tif
gdal_translate data/dem/burke-DEM03.tif data/cog.tif -co TILED=YES -co COMPRESS=DEFLATE
gdaladdo -r average data/cog.tif 2 4 8 16 32   

# contours, ogr2ogr can optionally -simplify 0.000015 
gdalinfo data/dem/burke-DEM03.tif
ogr2ogr -s_srs EPSG:4326 -t_srs EPSG:4326 data/elev/vlp-region.shp ./vlp-region.geojson

# warp DEM data to valdese-lake-park area, might need -r bilinear 
gdalwarp -t_srs EPSG:4326 -te -81.579752 35.756578 -81.531515 35.779734 data/dem/burke-DEM03.tif data/vlp-DEM03-box.tif

# down sample the data to reduce noisy contour edges, then upscale using cubic spline to complete the effect
gdalwarp -overwrite -ts 1024 0 -r lanczos data/vlp-DEM03-box.tif data/vlp-DEM03a.tif
gdalwarp -overwrite -ts 4096 0 -r cubicspline -cutline data/elev/vlp-region.shp data/vlp-DEM03a.tif data/vlp-DEM03.tif

# generate contours for every 10 feet of elevation, then remove short segments
gdal_contour -a elev data/vlp-DEM03.tif  data/elev/vlp_Contour.shp -i 10
ogr2ogr -overwrite -dialect SQLITE data/elev/vlp_Contour2.shp data/elev/vlp_Contour.shp -sql "SELECT * FROM  vlp_Contour WHERE ST_Length(GEOMETRY) > 0.001"
ogr2ogr -f GeoJSON data/vlp-Contour.geojson data/elev/vlp_Contour2.shp
tippecanoe -f -o data/vlp-contours.pmtiles -l contours -n "VLP Contours" -Z8 -z13 data/vlp-Contour.geojson

gdal_translate data/vlp-DEM03.tif data/vlp-cog.tif -co TILED=YES -co COMPRESS=DEFLATE
gdaldem hillshade data/vlp-DEM03.tif data/vlp-DEM03.png
gdaldem hillshade data/vlp-DEM03.tif data/vlp-DEM03.jpg

# 2 meter DEM for Valdese area (n36w082) from USGS
gdal_contour -a elev data/Valdese_n36w082_DEM.tif data/elev/n36w082_Contour.shp -i 2
ogr2ogr -f GeoJSON -s_srs data/elev/n36w082_Contour.prj -t_srs EPSG:4326 data/n36w082_Contour.geojson data/elev/n36w082_Contour.shp
tippecanoe -f -o data/burke-area-contours.pmtiles -l contours -n "Burke Contours" -Z8 -z13 data/n36w082_Contour.geojson
