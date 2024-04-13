const path = require('path');
const fs = require('fs');

function extractValue(a) {
	const v = Array.isArray(a) ? a[1] : a;
	return v || 0;
}

let fname = process.argv[2];
let parno_liststr = process.argv[3];

if (!fname || !fs.existsSync(fname) || !parno_liststr) {
	let cmd = process.argv[1];
	console.error(`Usage: ${cmd} jsonfile parno1,parno2,...`);
	process.exit(1);
}

let gj = {type:'FeatureCollection',features:[]};
let parno_list = parno_liststr.split(',');
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
