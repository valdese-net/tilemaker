from osgeo import ogr,osr
import debug

target_srs = osr.SpatialReference()
target_srs.ImportFromEPSG(4326)

burke = ogr.Open('./data/burke-boundary.geojson')
burkeLayer = burke.GetLayer()
burkeFeature = burkeLayer.GetFeature(0)
burkeGeomoetry = burkeFeature.GetGeometryRef()
burkeGeomoetry.Transform(osr.CoordinateTransformation(burkeLayer.GetSpatialRef(), target_srs))

parcelPts = ogr.Open('/vsizip/./data/parcels/burke-parcels-04-20-2026.zip/nc_burke_parcels_pt.shp')
parcelptLayer = parcelPts.GetLayer()
xparcelpt = osr.CoordinateTransformation(parcelptLayer.GetSpatialRef(), target_srs)

fdShapes = ogr.Open('/vsizip/./data/ncfd-fixed.shape.zip')
fdLayer = fdShapes.GetLayer()
xfd = osr.CoordinateTransformation(fdLayer.GetSpatialRef(), target_srs)

class ParcelPoint:
	__slots__ = ['id', 'val', 'pt', 'fd']
	def __init__(self, l: ogr.Feature, p: ogr.Geometry):
		self.id = l.GetField('NPARNO')
		self.val = l.GetField('PARVAL')
		
		self.pt = p.ExportToWkb()
		self.fd = None

class FireDistrict:
	def __init__(self, id: str, name: str):
		self.id = id
		self.name = name
		self.parcels = []

firedistricts = {}
parcels = {}

for ppt in parcelptLayer:
	pt = ppt.GetGeometryRef()
	if not pt or not pt.IsValid(): continue
	pt.Transform(xparcelpt)
	newparcel = ParcelPoint(ppt, pt)
	parcels[newparcel.id] = newparcel

for fd in fdLayer:
	fd_id = fd.GetField("FDID")
	if fd_id is None: continue

	fd_name = fd.GetField("firedepart")
	geo = fd.GetGeometryRef()

	if not geo or not geo.IsValid():
		print(f"Warning: Fire district geometry is missing. Skipping this feature. {fd_id}: {fd_name}")
		debug.print_geometry_stats(geo)
		continue  # Skip if geometry is missing

	geo.Transform(xfd)

	if not geo.Intersects(burkeGeomoetry):
		print(f'Skipping {fd_id}: {fd_name} does not intersect burke')
		continue

	print(f'Processing {fd_id}:{fd_name}')
	
	if fd_id in firedistricts:
		firedistrict = firedistricts[fd_id]
	else:
		firedistrict = FireDistrict(fd_id, fd_name)
		firedistricts[fd_id] = firedistrict

	for parcel in parcels.values():
		if parcel.fd is not None: continue

		pt = ogr.CreateGeometryFromWkb(parcel.pt)
		#if geo.Intersects(pt):
		if geo.Contains(pt):
			if parcel.fd is None:
				parcel.fd = fd_id
				firedistrict.parcels.append(parcel)
			elif parcel.fd != fd_id:
				print(f"Warning: Parcel {parcel.id} already assigned to FD {parcel.fd}. Now also intersects FD {fd_id}: {fd_name}.")

firedistricts = dict(sorted(firedistricts.items()))
parcels = dict(sorted(parcels.items()))

with open("data/burkefd.tsv", "w") as out:
	print(f"FDID\tFDNAME",file=out)
	for fd_id, firedistrict in firedistricts.items():
		if len(firedistrict.parcels) == 0: continue
		print(f"{fd_id}\t{firedistrict.name}",file=out)

with open("data/parcel2fd.tsv", "w") as out:
	print(f"NPARNO\tPARVAL\tFDID\tX\tY",file=out)
	for parcel in parcels.values():
		pt = ogr.CreateGeometryFromWkb(parcel.pt)
		print(f"{parcel.id}\t{parcel.val}\t{parcel.fd}\t{pt.GetX():.6f}\t{pt.GetY():.6f}",file=out)