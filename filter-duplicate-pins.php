<?php
define('APPDIR',__DIR__);

// after testing with this script, it bcame clear that the best approach for Burke County is simply to
// filter out non-zero PIN_EXT shapes in the parcel data. Doing this, all of the unrefined shape data
// gets avoided. This leaves some parcel shapes out of the file but avoids duplicate shapes.

function getproperty($line,$nm):string {
	return (preg_match(sprintf('~"%s": "([^"]+)"~',$nm),$line,$m)) ? trim($m[1]) : '';
}

$pinlist = [];
$fh = fopen('php://stdin','r');
while ($line = fgets($fh)) {
	$pin = getproperty($line,'PIN');
	$reid = getproperty($line,'REID');
	//$dupkey = sprintf('%s|%s',$pin,$reid);
	$dupkey = $pin;
	if ($pin) {
		if (!empty($pinlist[$dupkey])) {
			error_log('skipped duplicate: '.substr($line,0,32));	
			continue;
		}
		$pinlist[$dupkey] = 1;
	} elseif (strstr($line,'"geometry": { "type":')) {
		error_log('shape with no pin specified: '.substr($line,0,32));
		continue;
	}

	echo $line;
}
