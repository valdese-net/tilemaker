const path = require('path');
const fs = require('fs');

function extractValue(a) {
	const v = Array.isArray(a) ? a[1] : a;
	return v || 0;
}

let fname = process.argv[2];

if (!fname || !fs.existsSync(fname)) {
	console.error(`cannot open file '${fname}'`);
	process.exit(1);
}

let gj = {type:'FeatureCollection',features:[]};
let jsonData = fs.readFileSync(fname).toString();
let parcelList = JSON.parse(jsonData);
parcelList.forEach(e => {
	let pin = `${e.pin}`;
	let coords = e.coords;
	let geotype = 'Polygon';
	
	if (Array.isArray(coords[0][0][0])) {
		//coords = coords[0];
		geotype = 'MultiPolygon';
	}

	gj.features.push({
		'type': 'Feature',
		'properties': { 'name': pin },
		'geometry': {
			'type': geotype,
			'coordinates': coords
		}
	});
});

console.log(JSON.stringify(gj));
