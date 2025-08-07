<?php
define('APPDIR',__DIR__);
define('MAXLOOPS',10000000);

function cleanupval(&$s) {$s = trim(preg_replace('~[^a-zA-Z0-9]+~',' ',$s));}
$data = json_decode(file_get_contents('data/burke-addr-points.geojson'));

$tsvf = fopen('data/vurke-addresses.tsv','w');

$flds = ['PIN','ADDRESS','CITY','ZIPCODE','CITYLIM','ETJ'];
fwrite($tsvf,implode("\t",$flds));
fwrite($tsvf,"\tLONGITUDE\tLATITUDE\n");
$handledAddresses = [];
foreach ($data->features as $ftr) {
	cleanupval($ftr->properties->ADDRESS);
	if (empty($ftr->properties->PIN) || empty($ftr->properties->ADDRESS)) continue;

	$dupkey = $ftr->properties->ZIPCODE.$ftr->properties->ADDRESS;
	if (isset($handledAddresses[$dupkey])) continue;
	$handledAddresses[$dupkey] = 1;
	$count = 0;
	foreach ($flds as $fld) {
		if ($count++) fwrite($tsvf,"\t");
		fwrite($tsvf,strtoupper($ftr->properties->{$fld} ?? ''));
	}

	if ($geo = $ftr->geometry) fwrite($tsvf,sprintf("\t%.6f\t%.6f",$geo->coordinates[0],$geo->coordinates[1]));
	fwrite($tsvf,"\n");
}
fclose($tsvf);

/*****
sqlite3 data/burke-addresses.db
DROP TABLE IF EXISTS pin2addr;
CREATE TABLE IF NOT EXISTS pin2addr (PIN TEXT,ADDRESS TEXT,CITY TEXT,ZIPCODE TEXT,CITYLIM TEXT,ETJ TEXT,LONGITUDE REAL,LATITUDE REAL);
.mode tabs
.import data/burke-addresses.tsv pin2addr
PRAGMA busy_timeout = 500;
select ADDRESS,count(*) as count from pin2addr GROUP BY ADDRESS HAVING count > 1;
select * from pin2addr where ADDRESS LIKE '';

grep '3206 HIGH' data/burke-addr-points.geojson
grep '3206 HIGH' data/burke-addresses.tsv

100 CROSS ST|2
100 MILL ST|2
100 REEP ST|2
101 MOOSE ST|2
101 PINE ST|2
101 RAMSEY ST|2
101 RIDGE ST|2
102 BUTLER ST|2
103 WOODLAWN DR|2
105 WHITE ST|2
106 DOGWOOD DR|2
109 DOGWOOD DR|2
110 BUTLER ST|2
110 DOGWOOD DR|2
110 PINE ST|2
111 ALPINE ST|2
111 BUTLER ST|2
111 DOGWOOD DR|2
111 MOUNTAIN VIEW ST|2
111 PINE ST|2
111 REEP ST|2
113 DOGWOOD DR|2
120 HILLTOP ST|2
121 HILLTOP ST|2
121 PINE ST|2
130 HILLTOP ST|2
1466 US 70 W|2
1475 US 70 W|2
1562 US 70 W|2
1578 US 70 W|2
1584 US 70 W|2
201 RIDGE ST|2
201 WOODLAWN DR|2
202 HILLTOP ST|2
206 HILLTOP ST|2
210 HILLTOP ST|2
210 WOODLAWN DR|2
211 HILLTOP ST|2
******/
