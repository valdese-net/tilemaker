<?php
define('APPDIR',__DIR__);

require_once('db-helper.inc');
require_once('burke-county.inc');

define('ADDRESS_CSV',MAP_FOLDER.'/burke-addresses.csv');
define('ADDRESS_DB',MAP_FOLDER.'/burke-addresses.db');
define('ADDR_DB_PROPERTIES','PIN,ADDRESS,CITY,ZIPCODE,CITYLIM,ETJ');
define('ADDR_DB_GEOMETRY_ASXY','LONGITUDE,LATITUDE');
define('ADDR_DB_COLSPEC','PIN TEXT,ADDRESS TEXT,CITY TEXT,ZIPCODE TEXT,CITYLIM TEXT,ETJ TEXT,LONGITUDE REAL,LATITUDE REAL');
define('OWNER_CSV',MAP_FOLDER.'/burke-owners.csv');
define('OWNER_DB_PROPERTIES','REID,PIN,PIN_EXT,TOTAL_PROP_VALUE,ETJ,PROPERTY_OWNER,OWNER_MAIL_1,OWNER_MAIL_CITY,OWNER_MAIL_STATE,LOCATION_ADDR,PHYADDR_CITY');
define('OWNER_DB_COLSPEC','REID TEXT,PIN TEXT,PIN_EXT TEXT,TOTAL_PROP_VALUE INTEGER,ETJ TEXT,PROPERTY_OWNER TEXT,OWNER_MAIL_1 TEXT,OWNER_MAIL_CITY TEXT,OWNER_MAIL_STATE TEXT,LOCATION_ADDR TEXT,PHYADDR_CITY TEXT');

$addr_numericFields = ['STNUM'=>SQLITE3_INTEGER,'LONGITUDE'=>SQLITE3_FLOAT,'LATITUDE'=>SQLITE3_FLOAT];
$owner_numericFields = ['TOTAL_PROP_VALUE'=>SQLITE3_INTEGER];

$filterAddressChars = fn($v,$k) => strtoupper(trim(preg_replace('~[^a-zA-Z0-9]+~',' ',$v)));
$filterOwnerFields = function($v,$k) {
	if (in_array($k,['LOCATION_ADDR','OWNER_MAIL_1'])) return strtoupper(trim(preg_replace('~[^a-zA-Z0-9]+~',' ',$v)));
	return strtoupper(trim($v));
};

$db = new SQLite3(ADDRESS_DB);
// in order to use these databases in a read-only env, they cannot use journal_mode WAL
$db->exec('PRAGMA journal_mode = DELETE');
$db->exec('PRAGMA synchronous = FULL');

// code relies on the ogr2ogr tool at https://gdal.org/en/stable/programs/ogr2ogr.html 
// and the Burke County GIS dataset at https://www.burkenc.org/2495/Data-Sets
if (!file_exists(OWNER_CSV)) {
	$cmd = sprintf(
		'ogr2ogr -f CSV -sql "SELECT %s FROM PROD_PARCEL_VIEW_FC WHERE %s" %s %s',
		OWNER_DB_PROPERTIES,
		"PIN LIKE '%'",
		OWNER_CSV,
		BURKE_GDB
	);
	assert(exec($cmd) !== false,'failed to generate the owner CSV data');

	// rebuild the owners table
	$db->exec('DROP TABLE IF EXISTS owners');
	$db->exec('CREATE TABLE owners ('.OWNER_DB_COLSPEC.')');
	$db->exec('CREATE INDEX idx_OWNER_PIN ON owners(PIN)');
	$db->exec('CREATE INDEX idx_OWNER_ETJ ON owners(ETJ)');

	$ownercount = csvToDatabase(OWNER_CSV,$db,'owners',OWNER_DB_PROPERTIES,$owner_numericFields,$filterOwnerFields);

	printf("%d owners added\n",$ownercount);
}

if (!file_exists(ADDRESS_CSV)) {
	$cmd = sprintf(
		'ogr2ogr -f CSV -lco GEOMETRY=AS_XY -select %s -t_srs EPSG:4326 %s %s SiteStructureAddressPoints',
		ADDR_DB_PROPERTIES,
		ADDRESS_CSV,
		BURKE_GDB
	);
	assert(exec($cmd) !== false,'failed to generate the addr CSV data');

	// note that ogr -lco GEOMETRY=AS_XY places the XY coordinates at the front of the csv

	// rebuild the addrlist table
	$db->exec('DROP TABLE IF EXISTS addrlist');
	$db->exec('CREATE TABLE addrlist ('.ADDR_DB_COLSPEC.')');
	$db->exec('CREATE INDEX idx_PIN ON addrlist(PIN)');
	$db->exec('CREATE INDEX idx_CITYLIM ON addrlist(CITYLIM)');

	$addrcount = csvToDatabase(ADDRESS_CSV,$db,'addrlist',ADDR_DB_GEOMETRY_ASXY.','.ADDR_DB_PROPERTIES,$addr_numericFields,$filterAddressChars);

	printf("%d addresses added\n",$addrcount);
}

/*
sqlite3 data/burke-addresses.db
select distinct STREET_NAM from addrlist order by STREET_NAM;
select * from addrlist limit 10;
select * from addrlist where STNUM < 1;
select SUM(TOTAL_PROP_VALUE) from owners where (ETJ LIKE '%VALDESE%');

STNUM,PREDIR,STREET_NAM,TYPE,POSTDIR,UNITTYPE,UNIT,CITY,ZIPCODE,PIN,CITYLIM,ETJ,LONGITUDE,LATITUDE

select distinct PREDIR from addrlist order by PREDIR;
select distinct TYPE from addrlist order by TYPE;
select distinct POSTDIR from addrlist order by POSTDIR;
select distinct UNITTYPE from addrlist order by UNITTYPE;

*/
