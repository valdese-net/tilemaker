#!/bin/bash

cp $1 tmp_$1

for i in {1..10}
do
  gdalwarp -co COMPRESS=PACKBITS -overwrite -r cubicspline tmp_$1 smooth_$1
  cp smooth_$1 tmp_$1
done

rm contour_smooth.*
gdal_contour -a elev smooth_$1 contour_smooth.shp -i 10.0

ogr2ogr -overwrite -dialect SQLITE contour_smooth_reduced.shp contour_smooth.shp -sql "SELECT * FROM  contour_smooth WHERE ST_Length(GEOMETRY) > 100"