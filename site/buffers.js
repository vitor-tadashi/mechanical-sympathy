/*
 * Buffers: the model behind the buffer simulator, and a port of scripts/size-buffers.
 *
 * Two queues in series, simulated as a fluid in 10 microsecond steps: a ring that a drain
 * empties into a second buffer, which a reader empties. Packets that do not fit are dropped
 * and counted. report() prints exactly what scripts/size-buffers prints, so the page and the
 * script give the same answer. tools/check-buffers holds the two to the same golden files.
 *
 * The result is illustrative: it shows the shape of a burst, and it is not a measurement.
 * DOM-free, so that Node can load it.
 */
(function (root, factory) {
	'use strict';
	if (typeof module === 'object' && module.exports) {
		module.exports = factory();
	} else {
		root.Buffers = factory();
	}
}(typeof self !== 'undefined' ? self : this, function () {
	'use strict';

	var DT = 10; // microseconds per step

	var defaults = {
		stack: 'kernel', idle: 0, pre: 500, rate: 4, burst: 1500,
		ring: 512, drain: 1.5, app: 1, rcvbuf: 212992, truesize: 2304, packets: 0,
		pause: 0, pauseAt: -1, buf: 2048, queues: 1
	};

	var stacks = {
		kernel: {
			one: 'RX ring', two: 'socket buffer',
			c1: 'rx_missed_errors', c2: 'UdpRcvbufErrors'
		},
		onload: {
			one: 'VI RX ring (EF_RXQ_SIZE)', two: 'stack packet buffers (EF_MAX_RX_PACKETS)',
			c1: 'see onload_stackdump', c2: 'memory_pressure, oflow_drop'
		},
		dpdk: {
			one: 'RX ring', two: 'mempool and application queue',
			c1: 'imissed', c2: 'rx_nombuf, then imissed'
		}
	};

	function withDefaults(options) {
		var o = {};
		Object.keys(defaults).forEach(function (k) { o[k] = defaults[k]; });
		Object.keys(options || {}).forEach(function (k) { o[k] = options[k]; });
		if (o.pauseAt < 0) { o.pauseAt = o.pre; }
		return o;
	}

	function capacity2(o) {
		return o.packets > 0 ? o.packets : Math.floor(o.rcvbuf / o.truesize);
	}

	/* One run. A negative capacity means unlimited. Same order of operations as the awk program: arrivals join the queue, the drain takes its share in the same step, then the overflow is dropped. */
	function run(o, cap1, cap2, keep) {
		var endBurst = o.pre + o.burst;
		var pauseEnd = o.pause > 0 ? o.pauseAt + o.pause : 0;
		var horizon = (endBurst > pauseEnd ? endBurst : pauseEnd) + 50000;
		var q1 = 0, q2 = 0, d1 = 0, d2 = 0, p1 = 0, p2 = 0, f1 = -1, f2 = -1;
		var series = keep ? [] : null;
		for (var t = 0; ; t += DT) {
			var a = (t >= o.pre && t < endBurst) ? o.rate : o.idle;
			var r2 = (o.pause > 0 && t >= o.pauseAt && t < o.pauseAt + o.pause) ? 0 : o.app;
			q1 += a * DT;
			var out1 = Math.min(q1, o.drain * DT);
			q1 -= out1;
			if (cap1 >= 0 && q1 > cap1) {
				d1 += q1 - cap1;
				q1 = cap1;
				if (f1 < 0) { f1 = t; }
			}
			q2 += out1;
			var out2 = Math.min(q2, r2 * DT);
			q2 -= out2;
			if (cap2 >= 0 && q2 > cap2) {
				d2 += q2 - cap2;
				q2 = cap2;
				if (f2 < 0) { f2 = t; }
			}
			if (q1 > p1) { p1 = q1; }
			if (q2 > p2) { p2 = q2; }
			if (keep) { series.push({ t: t, q1: q1, q2: q2, d1: d1, d2: d2 }); }
			if (t >= endBurst && t >= pauseEnd && q1 < 1e-6 && q2 < 1e-6) { break; }
			if (t >= horizon) { break; }
		}
		return { drop1: d1, drop2: d2, peak1: p1, peak2: p2, first1: f1, first2: f2, series: series };
	}

	function ceilPackets(x) {
		var c = Math.floor(x);
		return c < x - 1e-9 ? c + 1 : c;
	}

	function round(x) { return Math.floor(x + 0.5); }
	function pad(s) { while (s.length < 18) { s += ' '; } return s; }
	function mpps(x) { return x.toFixed(3); }

	/** Everything the report and the page need. */
	function simulate(options, keep) {
		var o = withDefaults(options);
		var st = stacks[o.stack] || stacks.kernel;
		var cap1 = o.ring;
		var cap2 = capacity2(o);
		var actual = run(o, cap1, cap2, keep);
		var free = run(o, -1, -1, false);
		var need1 = ceilPackets(free.peak1);
		var need2 = ceilPackets(free.peak2);
		return {
			o: o, st: st, cap1: cap1, cap2: cap2, actual: actual,
			need1: need1, need2: need2,
			needRingKiB: ceilPackets(need1 * o.buf / 1024),
			needBytes: need2 * o.truesize,
			needRcvbufKiB: ceilPackets(need2 * o.truesize / 2 / 1024),
			ringKiB: ceilPackets(o.ring * o.buf / 1024)
		};
	}

	/** The text that scripts/size-buffers prints. */
	function report(options) {
		var s = simulate(options, false);
		var o = s.o, a = s.actual, st = s.st;
		var L = [];
		L.push('size-buffers: fluid model in ' + DT + ' us steps. Illustrative, not a measurement.');
		L.push(pad('stack') + o.stack);
		L.push(pad('arrival') + 'idle ' + mpps(o.idle) + ' Mpps, burst ' + mpps(o.rate) + ' Mpps for ' + o.burst + ' us from ' + o.pre + ' us');
		L.push(pad('stage 1') + st.one + ': ' + o.ring + ' packets, drained at ' + mpps(o.drain) + ' Mpps');
		if (o.packets > 0) {
			L.push(pad('stage 2') + st.two + ': ' + s.cap2 + ' packets, read at ' + mpps(o.app) + ' Mpps');
		} else {
			L.push(pad('stage 2') + st.two + ': ' + s.cap2 + ' packets (' + o.rcvbuf + ' B at ' + o.truesize + ' B each), read at ' + mpps(o.app) + ' Mpps');
		}
		L.push(pad('reader pause') + (o.pause > 0 ? o.pause + ' us from ' + o.pauseAt + ' us' : 'none'));
		L.push('');
		L.push(pad('dropped, stage 1') + round(a.drop1) + ' packets (' + st.c1 + ')');
		L.push(pad('dropped, stage 2') + round(a.drop2) + ' packets (' + st.c2 + ')');
		var first = 'none';
		if (a.first1 >= 0 && (a.first2 < 0 || a.first1 <= a.first2)) {
			first = 'stage 1 at ' + a.first1 + ' us';
		} else if (a.first2 >= 0) {
			first = 'stage 2 at ' + a.first2 + ' us';
		}
		L.push(pad('first drop') + first);
		L.push(pad('peak fill') + 'stage 1: ' + round(a.peak1) + ' of ' + s.cap1 + ', stage 2: ' + round(a.peak2) + ' of ' + s.cap2);
		L.push('');
		L.push('To lose nothing in this scenario:');
		L.push(pad('ring') + s.need1 + ' packets, ' + s.needRingKiB + ' KiB per queue at ' + o.buf + ' B');
		if (o.packets > 0) {
			L.push(pad('stage 2') + s.need2 + ' packets');
		} else if (o.stack === 'kernel') {
			L.push(pad('socket buffer') + s.need2 + ' packets, ' + s.needBytes + ' B, SO_RCVBUF request ' + s.needRcvbufKiB + ' KiB');
		} else {
			L.push(pad('stage 2') + s.need2 + ' packets, ' + s.needBytes + ' B');
		}
		L.push(pad('ring memory now') + s.ringKiB + ' KiB per queue, ' + (s.ringKiB * o.queues) + ' KiB for ' + o.queues + ' queue(s)');
		return L.join('\n');
	}

	/** Command-line arguments, the way scripts/size-buffers reads them. */
	var flags = {
		'--stack': 'stack', '--idle-mpps': 'idle', '--pre-us': 'pre', '--burst-mpps': 'rate', '--burst-us': 'burst',
		'--ring': 'ring', '--drain-mpps': 'drain', '--app-mpps': 'app', '--rcvbuf-bytes': 'rcvbuf', '--truesize': 'truesize',
		'--buffer-packets': 'packets', '--pause-us': 'pause', '--pause-at-us': 'pauseAt', '--buf-bytes': 'buf', '--queues': 'queues'
	};

	function parseArgs(line) {
		var words = line.trim().split(/\s+/);
		var o = {};
		for (var i = 0; i < words.length; i += 2) {
			var key = flags[words[i]];
			if (!key) { throw new Error('unknown argument ' + words[i]); }
			o[key] = key === 'stack' ? words[i + 1] : Number(words[i + 1]);
		}
		return o;
	}

	function commandLine(options) {
		var o = withDefaults(options);
		var d = defaults;
		var parts = ['scripts/size-buffers'];
		Object.keys(flags).forEach(function (flag) {
			var key = flags[flag];
			if (key === 'pauseAt' && o.pause <= 0) { return; }
			if (key === 'pauseAt' ? o.pauseAt === o.pre : o[key] === d[key]) { return; }
			parts.push(flag + ' ' + o[key]);
		});
		return parts.join(' ');
	}

	/* Scenarios for the traffic shapes of concepts/network-buffers.md. Each key is a fixture in scripts/fixtures/buffers, and args is that fixture's argument line (tools/check-buffers compares them). */
	var presets = {
		'microburst-default': {
			label: 'Microburst, default sizes',
			text: 'the burst of the concept page on a 512-slot ring and a 208 KiB socket buffer',
			args: '--stack kernel --ring 512 --burst-mpps 4 --burst-us 1500 --drain-mpps 1.5 --app-mpps 1 --rcvbuf-bytes 212992 --truesize 2304'
		},
		'microburst-tuned': {
			label: 'Microburst, tuned sizes',
			text: 'the same burst with the ring at the maximum and an 8 MiB socket buffer',
			args: '--stack kernel --ring 8160 --burst-mpps 4 --burst-us 1500 --drain-mpps 1.5 --app-mpps 1 --rcvbuf-bytes 8388608 --truesize 2304'
		},
		'consumer-pause': {
			label: 'Consumer pause',
			text: 'a steady 1 Mpps while the reader stops for 1 ms',
			args: '--stack kernel --idle-mpps 1 --burst-mpps 1 --burst-us 3000 --pre-us 0 --ring 4096 --drain-mpps 3 --app-mpps 2 --pause-us 1000 --pause-at-us 500 --rcvbuf-bytes 212992 --truesize 2304'
		},
		'overload-kernel': {
			label: 'Steady overload, kernel',
			text: '6 Mpps for 20 ms against a 1.5 Mpps drain: no buffer can hold it',
			args: '--stack kernel --burst-mpps 6 --burst-us 20000 --pre-us 0 --ring 8160 --drain-mpps 1.5 --app-mpps 1.5 --rcvbuf-bytes 8388608 --truesize 2304'
		},
		'flood-onload': {
			label: 'Small-packet flood, Onload',
			text: '6 Mpps for 20 ms drained by a polling thread at 7 Mpps',
			args: '--stack onload --burst-mpps 6 --burst-us 20000 --pre-us 0 --ring 4096 --drain-mpps 7 --app-mpps 7 --buffer-packets 24576 --truesize 2048'
		},
		'starved-dpdk': {
			label: 'Starved mempool, DPDK',
			text: 'a reader that is slower than the arrival, against a small mempool',
			args: '--stack dpdk --burst-mpps 10 --burst-us 3000 --pre-us 200 --ring 1024 --drain-mpps 14 --app-mpps 6 --buffer-packets 2048 --truesize 2304'
		}
	};

	return {
		DT: DT, defaults: defaults, stacks: stacks, presets: presets, flags: flags,
		simulate: simulate, report: report, parseArgs: parseArgs, commandLine: commandLine, withDefaults: withDefaults
	};
}));
