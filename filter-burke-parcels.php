<?php
// Burke County parcel shapes can appear multiple times in the GDB.
// Deduplicate any parcels with the same shape.
//
// After using this, the actual way to identify unique parcels is with the PARCEL_PK field, which is a unique identifier for each parcel.
// The PIN field is not unique and can be shared by multiple parcels, so it should not be used as the primary key for identifying parcels.
// The PARCEL_PK field should be used instead to ensure that each parcel is uniquely identified.

function do_error($msg,$ftr=false) {
	error_log($msg);
	if ($ftr) error_log(json_encode($ftr));
}

$d = json_decode(file_get_contents('php://stdin'),true);
$d1 = $d['features'];
$d2 = [];
$shapesigs = [];
foreach ($d1 as $ftr) {
	$shape = json_encode($ftr['geometry']);

	if (empty($ftr['properties']['PIN']) || empty($ftr['properties']['PARCEL_PK'])) {
		do_error('skipped shape with no PIN or PARCEL_PK', $ftr);
		continue;
	}

	$shapesig = md5($shape);
	if (!empty($shapesigs[$shapesig])) {
		do_error('skipped duplicate shape', $ftr);
		continue;
	}
	$shapesigs[$shapesig] = true;

	$d2[] = $ftr;
}

$d['features'] = $d2;
echo json_encode($d);
