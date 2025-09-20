# tilemaker

This creates vector tile aggregates for MapLibre. Assumes the following is available:

- wget
- osmconvert
- `tilemaker` Docker image

# data sources

- https://www.burkenc.org/2495/Data-Sets
- https://www.nconemap.gov/#directdatadownloads

# queries to find issues

SELECT * FROM 'addrlist' where ADDRESS='' OR CITYLIM='' LIMIT 0,30
SELECT * FROM 'owners' where LOCATION_ADDR='' OR PHYADDR_CITY='' LIMIT 0,30