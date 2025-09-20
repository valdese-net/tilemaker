<?php

/**
 * Loads a csv line by line, and stages each line as a row in the sqlite `tblName` table.
 * The `filterfield` can be used to apply custom transformations on the string data.
 */
function csvToDatabase(
	string $csvFilename,
	SQLite3 $db,
	string $tblName,
	string $dbFieldNames,
	array $addr_numericFields,
	callable $filterfield,
	int $batchSize=500
): int
{
	$insFieldNames = explode(',',$dbFieldNames);
	$insFldPlaceholders = array_fill(0,count($insFieldNames),'?');

	$db->exec('BEGIN');
	$dbins = $db->prepare(sprintf('INSERT INTO %s (%s) VALUES (%s)',$tblName,implode(',',$insFieldNames),implode(',',$insFldPlaceholders)));

	$csvf = new SplFileObject($csvFilename);
	$csvf->setFlags(SplFileObject::READ_CSV);
	$rowcount = 0;
	foreach ($csvf as $rowidx => $csv) {
		if (!$rowidx || (count($csv) < 2)) continue; // skip header row and empty rows
		$rowcount++;
		if (($rowcount % $batchSize) == 0) {
			printf("COMMIT, %d %s done\n",$rowcount,$tblName);
			$db->exec('COMMIT');
			$db->exec('BEGIN');
		}

		foreach ($insFieldNames as $i => $colname) {
			$v = $csv[$i]??'';
			$coltype = $addr_numericFields[$colname]??SQLITE3_TEXT;
			if ($coltype == SQLITE3_TEXT) $v = $filterfield($v,$colname);
			else if (!$v) $v = 0;
			$dbins->bindValue($i+1,$v,$coltype);
		}
		$r = $dbins->execute();
		assert($r,'insert failed');
		$dbins->reset();
	}
	$db->exec('END');
	
	return $rowcount;
}
