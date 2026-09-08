// Record the exact DAQ call sequence a euv3/euv4 sequence program produces.
//
// Why this exists: the sequence drives real hardware through a LabVIEW DAQ, so
// it cannot be executed here and a refactor of it cannot be checked by reading.
// This stubs every host object the program touches and appends one line per
// call, so two versions can be diffed: the refactor is correct exactly when the
// trace is byte-identical.
//
// An UNSTUBBED method throws rather than being ignored. That is the whole design:
// a silently-missing stub would truncate BOTH traces at the same point and the
// diff would pass while checking almost nothing. The first run of this harness
// stopped after 7 calls on `daq.setDigitalToPulseMode` — exactly that failure,
// caught because it was loud.
//
// Usage:  node euv3_trace.js <sequence.js>  > trace.txt

'use strict';
var fs = require('fs');
var srcPath = process.argv[2];
if (!srcPath) { process.stderr.write('usage: node euv3_trace.js <sequence.js>\n'); process.exit(2); }

var out = [];

function fmt(v) {
  // Round non-integers so a refactor that reassociates arithmetic identically
  // still compares equal, while a real change of value does not. 12 digits is
  // far below any physical resolution here (mV on a +-10 V DAC).
  if (typeof v === 'number') { return Number.isInteger(v) ? String(v) : v.toFixed(12); }
  if (v === null || v === undefined) { return String(v); }
  if (typeof v === 'object') { return '[obj]'; }
  return String(v);
}

function rec(objName, name, ret) {
  return function () {
    var a = Array.prototype.slice.call(arguments).map(fmt);
    out.push(objName + '.' + name + '(' + a.join(', ') + ')');
    return typeof ret === 'function' ? ret() : ret;
  };
}

// The host surface, enumerated from the source rather than guessed:
//   grep -oE '\b(daq|imaq|global|tcp)\.[a-zA-Z_][A-Za-z0-9_]*' <src> | sort -u
var daq = {};
['setAddress', 'setPort', 'setNumberOfAnalogPorts', 'initialize',
 'setAnalog', 'setDigital', 'setDigitalToPulseMode', 'end', 'run',
].forEach(function (m) { daq[m] = rec('daq', m); });

// imaq returns values the program then reads, so the stubs have to hand back
// shaped objects or the program dies on property access — which would again
// truncate both traces identically.
var imaq = {
  setAddress: rec('imaq', 'setAddress'),
  setPort: rec('imaq', 'setPort'),
  getImageData: rec('imaq', 'getImageData', function () {
    return { atoms: 0, fitPosX: 0, fitPosY: 0, fitWidthX: 0, fitWidthY: 0,
             peak: 0, offset: 0, temperature: 0 };
  }),
  getFullImage: rec('imaq', 'getFullImage', function () { return []; }),
  getFittedImage: rec('imaq', 'getFittedImage', function () { return []; }),
};

var labviewGlobal = {
  addPoint: rec('Global', 'addPoint'),
  getPoints: rec('Global', 'getPoints', function () { return []; }),
};

// `graph` is used as a bare identifier (graph.addListPlot). Whatever the host
// binds it to, the program only ever calls plotting methods on it.
var graph = {};
// Enumerated: grep -oE 'graph\.[a-zA-Z_][A-Za-z0-9_]*' <src> | sort -u
['addListPlot', 'clearData', 'setHorizontalLabel', 'setHorizontalLog',
 'setTitle', 'setVerticalLabel', 'setVerticalLog', 'show',
].forEach(function (m) { graph[m] = rec('graph', m); });

// The four host-injected globals, enumerated rather than guessed:
//   the only free identifiers in the source are imageData, storage, gui, counter.
// `counter` is the shot index the host increments between runs; 0 makes the
// trace the FIRST shot, which is the branch that writes the CSV header.
var storage = {
  makeKey: rec('storage', 'makeKey', 'ROWID'),
  saveImage: rec('storage', 'saveImage'),
  createCSV: rec('storage', 'createCSV', function () {
    return { put: rec('csv', 'put') };
  }),
};
var gui = {
  showImage: rec('gui', 'showImage'),
  getGraphFactory: rec('gui', 'getGraphFactory', function () {
    return { createOrLoadGraph: rec('graphFactory', 'createOrLoadGraph',
                                    function () { return graph; }) };
  }),
};

var globals = {
  storage: storage,
  gui: gui,
  counter: 0,
  imageData: { atoms: 0, fitNumberX: 0, fitNumberY: 0, fitWidthX: 0,
               fitWidthY: 0, fitPosX: 0, fitPosY: 0 },
  daq: daq,
  imaq: imaq,
  graph: graph,
  console: { log: rec('console', 'log') },
  Packages: {
    labview: {
      Global: labviewGlobal,
      TcpIp: { send: rec('TcpIp', 'send'), receive: rec('TcpIp', 'receive', ''),
               open: rec('TcpIp', 'open'), close: rec('TcpIp', 'close') },
    },
  },
};
for (var k in globals) { global[k] = globals[k]; }

// FREEZE TIME. `v687MOTFreq` compensates the ULE cavity drift from the last
// calibration date at +3.41 kHz/day using `new Date()`, and `Date.now()` times
// the run. Both are correct for the instrument and both make the trace
// non-deterministic: two runs of the SAME file differed in the 687 nm frequency
// at the 6th digit, which would swamp any refactor diff.
var FIXED_MS = Date.UTC(2026, 8, 2, 12, 0, 0);   // 2026-09-02 12:00 UTC
var RealDate = Date;
function FrozenDate(a, b, c, d, e, f, g) {
  if (!(this instanceof FrozenDate)) { return new FrozenDate(a); }
  if (arguments.length === 0) { return new RealDate(FIXED_MS); }
  if (arguments.length === 1) { return new RealDate(a); }
  return new RealDate(a, b, c, d, e, f, g);
}
FrozenDate.now = function () { return FIXED_MS; };
FrozenDate.parse = RealDate.parse;
FrozenDate.UTC = RealDate.UTC;
FrozenDate.prototype = RealDate.prototype;
global.Date = FrozenDate;

var src = fs.readFileSync(srcPath, 'utf8');
try {
  // Indirect eval keeps the program in global scope, which is where it expects
  // its `var`s to live — they are read by the functions it defines.
  (0, eval)(src);
} catch (e) {
  out.push('!! THREW: ' + (e && e.message ? e.message : String(e)));
}
process.stdout.write(out.join('\n') + '\n');
process.stderr.write('calls: ' + out.length + '\n');
