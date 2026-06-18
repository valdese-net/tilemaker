# Notes

This contains stuff to create vector pmtiles. Uses:

- `wget`
- `osmconvert`
- `tilemaker` (probably needs to be custom built)
- `tippecanoe` (probably needs to be custom built)

## tilemaker compiling and install 

```
git clone https://github.com/systemed/tilemaker.git
make
make prefix=~ MANPREFIX=~/share/man install
```

## data sources

- https://www.burkenc.org/2495/Data-Sets
- https://www.nconemap.gov/#directdatadownloads
	- [Fire Stations](https://www.nconemap.gov/datasets/6f4fe0c55b0d4cbb92877e461d698c29_0/about)
	- [Fire Districts](https://www.nconemap.gov/datasets/abc2d489a9484854b21ffb029eb45a98/explore)

## queries to find issues

SELECT * FROM 'addrlist' where ADDRESS='' OR CITYLIM='' LIMIT 0,30
SELECT * FROM 'owners' where LOCATION_ADDR='' OR PHYADDR_CITY='' LIMIT 0,30

## Expression samples for QGIS

```QGIS
with_variable('PublicParcels',string_to_array(@BRT_Public,',','0'),
with_variable('PrivateParcels',string_to_array(@BRT_Private,',','0'),
if(array_contains(@PrivateParcels,"PIN"),'yellow',
	if(array_contains(@PublicParcels,"PIN"),'green','#EEEEEE')
)))
```

```QGIS
with_variable('pb',concat(',',"PIN",','),
	if(strpos(@BRT_Private,@pb) > 0,
		'yellow',
		if(strpos(@BRT_Public,@pb) > 0,
			'green',
			'#EEEEEE88'
		)
	)
)
```