'use strict';

/* buffers-ui.js - the DOM side of the buffer simulator. The model lives in buffers.js. */
(function () {
	const $ = (id) => document.getElementById(id);
	const B = window.Buffers;
	const SVG = 'http://www.w3.org/2000/svg';

	const KiB = 1024;
	const MiB = 1024 * KiB;

	/* One entry per control. "range" is a slider, "select" a list, "number" a box. */
	const FIELDS = [
		{ group: 'fields-arrival', key: 'rate', label: 'Arrival rate during the burst', unit: 'Mpps', type: 'range', min: 0.5, max: 20, step: 0.5 },
		{ group: 'fields-arrival', key: 'burst', label: 'Burst length', unit: 'µs', type: 'range', min: 100, max: 20000, step: 100 },
		{ group: 'fields-arrival', key: 'idle', label: 'Arrival rate outside the burst', unit: 'Mpps', type: 'range', min: 0, max: 10, step: 0.5 },
		{ group: 'fields-arrival', key: 'pause', label: 'Reader pause', unit: 'µs', type: 'range', min: 0, max: 5000, step: 100, hint: 'The reader stops for this long when the burst starts.' },
		{ group: 'fields-queues', key: 'ring', label: 'Ring size', unit: 'packets', type: 'select', options: [256, 512, 1024, 2048, 4096, 8160], hint: 'ethtool -G rx N, or EF_RXQ_SIZE.' },
		{ group: 'fields-queues', key: 'drain', label: 'Ring drain rate', unit: 'Mpps', type: 'range', min: 0.5, max: 15, step: 0.5, hint: 'What NAPI, or a polling core, can take from the ring.' },
		{
			group: 'fields-queues', key: 'rcvbuf', label: 'Second buffer', unit: 'bytes', type: 'select',
			options: [212992, MiB, 4 * MiB, 8 * MiB, 32 * MiB, 128 * MiB],
			format: (v) => (v === 212992 ? '208 KiB (kernel default)' : (v / MiB) + ' MiB'),
			hint: 'SO_RCVBUF after doubling, or rmem_default.'
		},
		{ group: 'fields-queues', key: 'truesize', label: 'Bytes charged per packet', unit: 'bytes', type: 'select', options: [768, 2048, 2304], hint: 'The truesize of a small packet. See ss -m.' },
		{ group: 'fields-queues', key: 'packets', label: 'Second buffer in packets', unit: 'packets', type: 'number', min: 0, max: 1000000, step: 1, hint: '0 means: use the size in bytes above.' },
		{ group: 'fields-queues', key: 'app', label: 'Reader rate', unit: 'Mpps', type: 'range', min: 0.5, max: 15, step: 0.5, hint: 'What your thread reads from the second buffer.' }
	];

	let state = B.withDefaults(B.parseArgs(B.presets['microburst-default'].args));
	const controls = {};

	const number = (v) => (Math.round(v * 1000) / 1000).toString();

	function buildFields() {
		FIELDS.forEach((f) => {
			const wrap = document.createElement('div');
			wrap.className = 'field';
			const id = 'f-' + f.key;
			const label = document.createElement('label');
			label.htmlFor = id;
			wrap.appendChild(label);
			let input;
			if (f.type === 'select') {
				input = document.createElement('select');
				f.options.forEach((v) => {
					const o = document.createElement('option');
					o.value = String(v);
					o.textContent = f.format ? f.format(v) : String(v);
					input.appendChild(o);
				});
			} else {
				input = document.createElement('input');
				input.type = f.type;
				input.min = String(f.min);
				input.max = String(f.max);
				input.step = String(f.step);
			}
			input.id = id;
			input.addEventListener('input', () => {
				state[f.key] = Number(input.value);
				if (f.key === 'pause') { state.pauseAt = state.pre; }
				render();
			});
			wrap.appendChild(input);
			if (f.hint) {
				const hint = document.createElement('span');
				hint.className = 'hint';
				hint.textContent = f.hint;
				wrap.appendChild(hint);
			}
			$(f.group).appendChild(wrap);
			controls[f.key] = { f, input, label };
		});
	}

	function syncFields() {
		FIELDS.forEach((f) => {
			const c = controls[f.key];
			let value = state[f.key];
			if (f.type === 'select' && !f.options.includes(value)) {
				const o = document.createElement('option');
				o.value = String(value);
				o.textContent = (f.format ? f.format(value) : String(value)) + ' (from the scenario)';
				c.input.appendChild(o);
			}
			c.input.value = String(value);
			const shown = f.type === 'select' && f.format ? f.format(value) : number(value);
			c.label.textContent = f.label + ': ' + shown + (f.type === 'select' && f.format ? '' : ' ' + f.unit);
		});
		$('stack').value = state.stack;
	}

	function buildPresets() {
		Object.keys(B.presets).forEach((key) => {
			const b = document.createElement('button');
			b.type = 'button';
			b.className = 'btn secondary';
			b.textContent = B.presets[key].label;
			b.addEventListener('click', () => {
				state = B.withDefaults(B.parseArgs(B.presets[key].args));
				$('preset-text').textContent = B.presets[key].text + '.';
				syncFields();
				render();
			});
			$('presets').appendChild(b);
		});
		$('preset-text').textContent = B.presets['microburst-default'].text + '.';
	}

	function el(name, attrs, text) {
		const e = document.createElementNS(SVG, name);
		Object.keys(attrs || {}).forEach((k) => e.setAttribute(k, attrs[k]));
		if (text !== undefined) { e.textContent = text; }
		return e;
	}

	/** Nice tick step for a time axis in microseconds. */
	function niceStep(max) {
		const steps = [100, 200, 500, 1000, 2000, 5000, 10000, 20000, 50000, 200000, 500000];
		return steps.find((s) => max / s <= 8) || 500000;
	}

	function panel(svg, y0, h, title, series, key, dropKey, cap, tMax) {
		const x0 = 60, w = 680;
		const peak = series.reduce((m, p) => Math.max(m, p[key]), 0);
		const top = Math.max(cap, peak, 1) * 1.08;
		const X = (t) => x0 + (t / tMax) * w;
		const Y = (v) => y0 + h - (v / top) * h;
		svg.appendChild(el('text', { x: x0, y: y0 - 10, class: 'ct' }, title));
		svg.appendChild(el('rect', { x: x0, y: y0, width: w, height: h, class: 'cbox' }));

		// bands where this stage is dropping
		let start = null;
		series.forEach((p, i) => {
			const prev = i === 0 ? 0 : series[i - 1][dropKey];
			const dropping = p[dropKey] > prev + 1e-9;
			if (dropping && start === null) { start = p.t; }
			if (!dropping && start !== null) {
				svg.appendChild(el('rect', { x: X(start), y: y0, width: Math.max(1.5, X(p.t) - X(start)), height: h, class: 'cdrop' }));
				start = null;
			}
		});
		if (start !== null) {
			svg.appendChild(el('rect', { x: X(start), y: y0, width: Math.max(1.5, X(tMax) - X(start)), height: h, class: 'cdrop' }));
		}

		// capacity line
		svg.appendChild(el('line', { x1: x0, x2: x0 + w, y1: Y(cap), y2: Y(cap), class: 'ccap' }));
		svg.appendChild(el('text', { x: x0 - 6, y: Y(cap) + 4, class: 'ca', 'text-anchor': 'end' }, String(cap)));
		svg.appendChild(el('text', { x: x0 - 6, y: y0 + h + 4, class: 'ca', 'text-anchor': 'end' }, '0'));

		// fill line, at most about 400 points
		const stride = Math.max(1, Math.floor(series.length / 400));
		let d = '';
		series.forEach((p, i) => {
			if (i % stride !== 0 && i !== series.length - 1) { return; }
			d += (d ? 'L' : 'M') + X(p.t).toFixed(1) + ' ' + Y(p[key]).toFixed(1);
		});
		svg.appendChild(el('path', { d: d, class: 'cline' }));

		// time axis
		const step = niceStep(tMax);
		for (let t = 0; t <= tMax + 1; t += step) {
			svg.appendChild(el('line', { x1: X(t), x2: X(t), y1: y0 + h, y2: y0 + h + 4, class: 'ctick' }));
			svg.appendChild(el('text', { x: X(t), y: y0 + h + 16, class: 'ca', 'text-anchor': 'middle' }, (t / 1000) + ' ms'));
		}
	}

	function drawChart(sim) {
		const series = sim.actual.series;
		const tMax = Math.max(series[series.length - 1].t, 1000);
		const svg = el('svg', { viewBox: '0 0 760 400', role: 'img', 'aria-label': 'Fill level of each queue over time, with the capacity and the time when packets are dropped' });
		svg.appendChild(el('title', {}, 'Queue fill over time'));
		panel(svg, 34, 130, sim.st.one + ': ' + sim.cap1 + ' packets, ' + Math.round(sim.actual.drop1) + ' dropped', series, 'q1', 'd1', sim.cap1, tMax);
		panel(svg, 224, 130, sim.st.two + ': ' + sim.cap2 + ' packets, ' + Math.round(sim.actual.drop2) + ' dropped', series, 'q2', 'd2', sim.cap2, tMax);
		$('chart').textContent = '';
		$('chart').appendChild(svg);
	}

	const fmt = (n) => Math.round(n).toLocaleString('en-US');

	function verdict(sim) {
		const a = sim.actual;
		const d1 = Math.round(a.drop1), d2 = Math.round(a.drop2);
		const box = $('verdict');
		if (sim.unbounded) {
			box.className = 'verdict bad';
			box.textContent = 'The queues never empty within 2 s of simulated time, so no finite size is enough. The arrival outside the burst is not below what the drain and the reader can take, or the reader has stopped.';
			return;
		}
		box.className = 'verdict ' + (d1 + d2 === 0 ? 'good' : 'bad');
		if (d1 + d2 === 0) {
			box.textContent = 'Nothing is lost. The ring peaks at ' + fmt(a.peak1) + ' of ' + fmt(sim.cap1) + ' slots, and the second buffer at ' + fmt(a.peak2) + ' of ' + fmt(sim.cap2) + '.';
			return;
		}
		const parts = [];
		if (d1 > 0) { parts.push(fmt(d1) + ' packets are dropped at the ring (' + sim.st.c1 + '), first at ' + a.first1 + ' µs'); }
		if (d2 > 0) { parts.push(fmt(d2) + ' are dropped at the second buffer (' + sim.st.c2 + '), first at ' + a.first2 + ' µs'); }
		box.textContent = parts.join('. ') + '. To lose nothing: a ring of at least ' + fmt(sim.need1) + ' slots and a second buffer of at least ' + fmt(sim.need2) + ' packets.';
	}

	function render() {
		const sim = B.simulate(state, true);
		syncLabels();
		verdict(sim);
		drawChart(sim);
		$('report').textContent = B.report(state);
		$('cmd').textContent = B.commandLine(state);
	}

	function syncLabels() {
		FIELDS.forEach((f) => {
			const c = controls[f.key];
			const shown = f.type === 'select' && f.format ? f.format(state[f.key]) : number(state[f.key]);
			c.label.textContent = f.label + ': ' + shown + (f.type === 'select' && f.format ? '' : ' ' + f.unit);
		});
	}

	function copyButton(buttonId, sourceId) {
		const button = $(buttonId);
		button.addEventListener('click', () => {
			const text = $(sourceId).textContent;
			if (navigator.clipboard && navigator.clipboard.writeText) {
				navigator.clipboard.writeText(text).then(() => {
					button.textContent = 'Copied';
					setTimeout(() => { button.textContent = 'Copy'; }, 1500);
				}, () => { button.textContent = 'Select and copy'; });
			} else {
				button.textContent = 'Select and copy';
			}
		});
	}

	buildFields();
	buildPresets();
	$('stack').addEventListener('change', () => { state.stack = $('stack').value; render(); });
	copyButton('copy-report', 'report');
	copyButton('copy-cmd', 'cmd');
	syncFields();
	render();
}());
