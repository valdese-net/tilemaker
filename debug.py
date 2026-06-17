from osgeo import ogr,osr

def print_geometry_stats(geom):
	"""Debug prints core statistics of an osgeo ogr Geometry object."""
	if geom is None:
		print("Geometry is None")
		return

	# Basic Info
	geom_name = geom.GetGeometryName()
	geom_type = geom.GetGeometryType()
	geom_type_name = ogr.GeometryTypeToName(geom_type)
	
	print("-" * 40)
	print(f"Geometry Name  : {geom_name}")
	print(f"Geometry Type  : {geom_type_name} (Code: {geom_type})")
	print(f"Is Valid?      : {geom.IsValid()}")
	print(f"Is Empty?      : {geom.IsEmpty()}")
	print(f"Dimension      : {geom.GetDimension()}")
	print(f"Coordinate Dim : {geom.GetCoordinateDimension()}")
	
	# Coordinate Reference System
	srs = geom.GetSpatialReference()
	srs_wkt = srs.ExportToWkt() if srs else "None"
	print(f"Spatial Ref    : {srs_wkt}")

	# Spatial Bounds
	# Returns (minX, maxX, minY, maxY)
	env = geom.GetEnvelope() 
	print(f"Envelope (BBox): Min X: {env[0]:.6f}, Max X: {env[1]:.6f}")
	print(f"                 Min Y: {env[2]:.6f}, Max Y: {env[3]:.6f}")
	
	# Geometry counts and point vertices
	geom_count = geom.GetGeometryCount()
	if geom_count > 0:
		print(f"Sub-geometries : {geom_count}")
		for i in range(geom_count):
			sub_geom = geom.GetGeometryRef(i)
			print(f"  - Sub-geom {i}: {sub_geom.GetGeometryName()} (Points: {sub_geom.GetPointCount()})")
	else:
		point_count = geom.GetPointCount()
		print(f"Point Count    : {point_count}")
		if point_count > 0 and geom.GetCoordinateDimension() >= 2:
			pts = geom.GetPoints()
			# Print the first and last few points to avoid overwhelming the console
			if point_count > 5:
				print(f"First Point    : {pts[0]}")
				print(" ... [points hidden] ...")
				print(f"Last Point     : {pts[-1]}")
			else:
				print(f"Points         : {pts}")
				
	print("-" * 40)
