const path = require('path');
const fs = require('fs');

function extractValue(a) {
	const v = Array.isArray(a) ? a[1] : a;
	return v || 0;
}

let fname = process.argv[2];
let parno_listfile = process.argv[3];

if (!fname || !fs.existsSync(fname) || !parno_listfile || !fs.existsSync(parno_listfile)) {
	let cmd = process.argv[1];
	console.error(`Usage: ${cmd} jsonfile parnofile`);
	process.exit(1);
}

let gj = {type:'FeatureCollection',features:[]};
let parno_list = fs.readFileSync(parno_listfile).toString().trim().split('\n');
let parcelList = JSON.parse(fs.readFileSync(fname).toString());
parcelList.features.forEach(e => {
	let parno = e.properties.PARNO || '';

	if (parno_list.includes(parno)) {
		let coord = e.coordinates;

		gj.features.push({
			'type': 'Feature',
			'properties': { 'pin': parno },
			'geometry': e.geometry
		});
	}
});

console.log(JSON.stringify(gj));

let c1 = parno_list.length;
let c2 = gj.features.length;
console.warn(`${c1} pins, ${c2} parcels found`);
