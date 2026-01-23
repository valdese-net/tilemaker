# Usage: smooth.sh MyDEMFile.tif

# Variables:
# Amount of blurring of flat areas {radius}x{sigma}
BLUR_flat_areas="20x35"

# Amount of blurring of the alpha mask, too little can lead to artifacts
BLUR_mask="40x35"

# Controls where to draw the line between steep and flat areas, suitable values
# can be found by looking at a slope map in QGIS and playing with min/max values
RAMP_start="10"
RAMP_end="20"

f=$(echo $1| cut -d'.' -f 1)

# Blur DEM
listgeo -tfw $1
mv $f.tfw blurred.tfw
convert -quiet -blur $BLUR_flat_areas $1 blurred.tif

# Create slopemap
gdaldem slope blurred.tif blurred_slope.tif -of GTiff

# Color slopemaps
ramp=$RAMP_start" 0 0 0
$RAMP_end 255 255 255"
echo "$ramp" > ramp.txt

ramp_inv=$RAMP_start" 255 255 255
$RAMP_end 0 0 0"
echo "$ramp_inv" > ramp_inverse.txt

gdaldem color-relief blurred_slope.tif ramp.txt slope_colored.tif
gdaldem color-relief blurred_slope.tif ramp_inverse.txt slope_colored_inverse.tif

# Make slopes singlebanded
gdal_translate -b 1 -co "TFW=YES" slope_colored.tif slope1band.tif
gdal_translate -b 1 -co "TFW=YES" slope_colored_inverse.tif slope1band_inverse.tif

convert -quiet -blur $BLUR_mask slope1band.tif slope1band_blurred.tif
convert -quiet -blur $BLUR_mask slope1band_inverse.tif slope1band_inverse_blurred.tif

mv slope1band.tfw slope1band_blurred.tfw
mv slope1band_inverse.tfw slope1band_inverse_blurred.tfw

# Mask high res DEM
gdal_merge.py $1 slope1band_blurred.tif -o masked.tif -separate -ot Float32
gdal_translate -b 1 -b 2 -colorinterp gray,alpha masked.tif masked2.tif

# Mask blurred DEM
gdal_merge.py blurred.tif slope1band_inverse_blurred.tif -o masked_inverse.tif -separate -ot Float32
gdal_translate -b 1 -b 2 -colorinterp gray,alpha masked_inverse.tif masked2_inverse.tif

# Merge the two
gdalwarp masked2_inverse.tif masked2.tif Smooth.tif

# Cleanup
rm masked*
rm blurred*
rm slope*
rm ramp*
