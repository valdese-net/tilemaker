from osgeo import ogr,osr
import csv

fd = {}
fs = {}
fs_pt = {}
parcels = {}

target_srs = osr.SpatialReference()
target_srs.ImportFromEPSG(4326)

with open('data/burkefd.tsv', 'r') as file:
	reader = csv.DictReader(file, delimiter="\t")
	for row in reader:
		fd[row['FDID']] = row['FDNAME']

stations = ogr.Open('/vsizip/./data/NC_Fire_Stations_7200722316549403871.zip/Fire_Stations.shp')
stationLayer = stations.GetLayer()
xstation = osr.CoordinateTransformation(stationLayer.GetSpatialRef(), target_srs)

for station in stationLayer:
	id = station.GetFID()
	name = station.GetField('DEPT_NAME')
	fd_id = station.GetField('FD_ID')
	station_num = station.GetField('STATION_NU')

	if not fd_id in fd: continue

	stationGeo = station.GetGeometryRef()
	if not stationGeo or not stationGeo.IsValid():
		print(f"Warning: Station geometry is missing. Skipping this feature.")
		continue

	stationGeo.Transform(xstation)

	X = stationGeo.GetX()
	Y = stationGeo.GetY()

	fs[id] = {"id": id, "name": name, "FDID": fd_id, "station_num": station_num, "X": X, "Y": Y}

	station_pt = ogr.Geometry(ogr.wkbPoint)
	station_pt.AddPoint(float(X), float(Y))
	fs_pt[id] = station_pt

with open('data/parcel2fd.tsv', 'r') as file:
	reader = csv.DictReader(file, delimiter="\t")
	for row in reader:
		parcels[row['NPARNO']] = row

parcelsWithCloserFS = 0

for parcel in parcels.values():
	ppt = ogr.Geometry(ogr.wkbPoint)
	ppt.AddPoint(float(parcel['X']), float(parcel['Y']))

	fdpt_id = None
	fdpt_d = float('inf')
	closest_id = None
	closest_d = float('inf')
	
	parcel['FDPenalty'] = 0.0

	for stationid,stationpt in fs_pt.items():
		d = ppt.Distance(stationpt)
		if d < closest_d:
			closest_d = d
			closest_id = stationid

		if (fs[stationid]['FDID'] == parcel['FDID']) and d < fdpt_d:
			fdpt_d = d
			fdpt_id = stationid

	parcel['FDStation'] = fdpt_id
	parcel['NearestStation'] = closest_id
	if (fdpt_id is not None and closest_id != fdpt_id):
		parcel['FDPenalty'] = (fdpt_d - closest_d) 
		parcelsWithCloserFS += 1

with open("data/burkefirestations.tsv", "w") as out:
	print(f"STATIONID\tFDID\tNAME\tNUM\tX\tY",file=out)
	for stationid, station in fs.items():
		print(f"{stationid}\t{station['FDID']}\t{station['name']}\t{station['station_num']}\t{station['X']:.6f}\t{station['Y']:.6f}",file=out)

with open("data/nearestfd.tsv", "w") as out:
	print(f"NPARNO\tPARVAL\tFDID\tFDStation\tNearestStation\tFDPenalty\tX\tY",file=out)
	for parcel in parcels.values():
		print(f"{parcel['NPARNO']}\t{parcel['PARVAL']}\t{parcel['FDID']}\t{parcel['FDStation']}\t{parcel['NearestStation']}\t{parcel['FDPenalty']}\t{parcel['X']}\t{parcel['Y']}",file=out)

print(f"Parcels with closer fire stations: {parcelsWithCloserFS} out of {len(parcels)} ({(parcelsWithCloserFS/len(parcels))*100:.2f}%)")