<?php
define('APPDIR',__DIR__);

define('MAP_FOLDER',__DIR__.'/data');
define('BURKE_GDB',MAP_FOLDER.'/burke_20250624.gdb.zip');
define('ADDRESS_CSV',MAP_FOLDER.'/burke-addresses.csv');
define('ADDRESS_DB',MAP_FOLDER.'/burke-addresses.db');
define('ADDR_DB_PROPERTIES','STNUM,PREDIR,STREET_NAM,TYPE,POSTDIR,UNITTYPE,UNIT,CITY,ZIPCODE,PIN,CITYLIM,ETJ');
define('ADDR_DB_GEOMETRY_ASXY','LONGITUDE,LATITUDE');
define('ADDR_DB_COLSPEC','STNUM INTEGER,PREDIR TEXT,STREET_NAM TEXT,TYPE TEXT,POSTDIR TEXT,UNITTYPE TEXT,UNIT TEXT,CITY TEXT,ZIPCODE TEXT,PIN TEXT,CITYLIM TEXT,ETJ TEXT,LONGITUDE REAL,LATITUDE REAL');

$nontextFields = ['STNUM'=>SQLITE3_INTEGER,'LONGITUDE'=>SQLITE3_FLOAT,'LATITUDE'=>SQLITE3_FLOAT];

if (!file_exists(ADDRESS_CSV)) {
	// https://gdal.org/en/stable/programs/ogr2ogr.html and https://www.burkenc.org/2495/Data-Sets
	$cmd = sprintf(
		'ogr2ogr -f CSV -lco GEOMETRY=AS_XY -select %s -t_srs EPSG:4326 %s %s SiteStructureAddressPoints',
		ADDR_DB_PROPERTIES,
		ADDRESS_CSV,
		BURKE_GDB
	);
	assert(exec($cmd) !== false,'failed to generate the CSV data');
}

// open the db and rebuild the addrlist table
$db = new SQLite3(ADDRESS_DB);
$db->exec('PRAGMA journal_mode = WAL');
$db->exec('PRAGMA synchronous = normal');
$db->exec('DROP TABLE IF EXISTS addrlist');
$db->exec('CREATE TABLE addrlist ('.ADDR_DB_COLSPEC.')');
$db->exec('CREATE INDEX idx_PIN ON addrlist(PIN)');
$db->exec('CREATE INDEX idx_CITYLIM ON addrlist(CITYLIM)');

$csvFieldArray = explode(',',ADDR_DB_GEOMETRY_ASXY.','.ADDR_DB_PROPERTIES);
$insFldPlaceholders = array_fill(0,count($csvFieldArray),'?');
$db->exec('BEGIN');
$dbins = $db->prepare(sprintf('INSERT INTO addrlist (%s) VALUES (%s)',implode(',',$csvFieldArray),implode(',',$insFldPlaceholders)));

// note that ogr -lco GEOMETRY=AS_XY places the XY coordinates at the front of the csv
$csvf = new SplFileObject(ADDRESS_CSV);
$csvf->setFlags(SplFileObject::READ_CSV);
$addrcount = 0;
foreach ($csvf as $rowidx => $csv) {
	if (!$rowidx || (count($csv) < 4)) continue; // skip header row and empty row
	$addrcount++;
	if (($addrcount % 5000) == 0) {
		printf("COMMIT, %d addresses done\n",$addrcount);
		$db->exec('COMMIT');
		$db->exec('BEGIN');
	}

	foreach ($csvFieldArray as $i => $colname) {
		$v = $csv[$i]??'';
		$coltype = $nontextFields[$colname]??SQLITE3_TEXT;
		if ($coltype == SQLITE3_TEXT) $v = strtoupper(trim(preg_replace('~[^a-zA-Z0-9]+~',' ',$v)));
		else if (!$v) $v = 0;
		$dbins->bindValue($i+1,$v,$coltype);
	}
	$r = $dbins->execute();
	assert($r,'insert failed');
	$dbins->reset();
}
$db->exec('END');

printf("%d addresses added\n",$addrcount);

/*
sqlite3 data/burke-addresses.db
select distinct STREET_NAM from addrlist order by STREET_NAM;
select * from addrlist limit 10;
select * from addrlist where STNUM < 1;

STNUM,PREDIR,STREET_NAM,TYPE,POSTDIR,UNITTYPE,UNIT,CITY,ZIPCODE,PIN,CITYLIM,ETJ,LONGITUDE,LATITUDE

select distinct PREDIR from addrlist order by PREDIR;
select distinct TYPE from addrlist order by TYPE;
select distinct POSTDIR from addrlist order by POSTDIR;
select distinct UNITTYPE from addrlist order by UNITTYPE;

*/
