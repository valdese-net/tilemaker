#!/bin/bash
mkdir -p data

# fetch the latest for North Carolina https://download.geofabrik.de/north-america/us/north-carolina-latest.osm.pbf
wget https://download.geofabrik.de/north-america/us/north-carolina-latest.osm.pbf -q --show-progress -N -P ./data

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

docker run -v ./:/srv -i -t --rm tilemaker /srv/data/north-carolina-latest.osm.pbf --output=/srv/data/nc.pmtiles --config /srv/tilemaker-allpaths.json --process /srv/tilemaker-allpaths.lua
docker run -v ./:/srv -i -t --rm tilemaker /srv/data/burke.osm.pbf --output=/srv/data/burke.pmtiles --config /srv/tilemaker-allpaths.json --process /srv/tilemaker-allpaths.lua
docker run -v ./:/srv -i -t --rm tilemaker /srv/data/valdese.osm.pbf --output=/srv/data/valdese.pmtiles --config /srv/tilemaker-allpaths.json --process /srv/tilemaker-allpaths.lua
docker run -v ./:/srv -i -t --rm tilemaker /srv/data/vlp.osm.pbf --output=/srv/data/vlp.pmtiles --config /srv/tilemaker-allpaths.json --process /srv/tilemaker-allpaths.lua

# valdese-area generated via https://app.protomaps.com/
docker run -v ./:/srv -i -t --rm tilemaker /srv/data/valdese-area.osm.pbf --output=/srv/data/valdese-area.pmtiles --config /srv/tilemaker-vlp.json --process /srv/tilemaker-vlp.lua

#pmtiles convert valdese.mbtiles valdese.pmtiles
#pmtiles convert burke.mbtiles burke.pmtiles

