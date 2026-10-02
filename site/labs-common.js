// labs-common.js - small helpers shared by the labs: a seeded random generator, percentiles,
// number formatting and two tiny SVG charts. No dependencies.
"use strict";

const Labs = (function () {
	// mulberry32: a small, fast, seeded generator, so that a run is the same every time.
	function rng(seed) {
		let a = seed >>> 0;
		return function () {
			a = (a + 0x6d2b79f5) >>> 0;
			let t = a;
			t = Math.imul(t ^ (t >>> 15), t | 1);
			t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
			return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
		};
	}

	function percentiles(values) {
		const v = Float64Array.from(values).sort();
		const at = function (p) { return v[Math.min(v.length - 1, Math.floor(p * v.length))]; };
		return { p50: at(0.5), p99: at(0.99), p999: at(0.999), max: v[v.length - 1], n: v.length };
	}

	function us(x) {
		if (x >= 1000) return (x / 1000).toFixed(x >= 10000 ? 0 : 1) + " ms";
		if (x >= 100) return Math.round(x) + " µs";
		if (x >= 10) return x.toFixed(0) + " µs";
		return x.toFixed(1) + " µs";
	}

	const NS = "http://www.w3.org/2000/svg";
	function el(name, attrs, text) {
		const e = document.createElementNS(NS, name);
		for (const k in attrs) e.setAttribute(k, attrs[k]);
		if (text !== undefined) e.textContent = text;
		return e;
	}

	// A percentile ladder on a log scale from 1 µs to 100 ms: one bar per percentile.
	function ladder(container, rows, label) {
		const w = 640, rowH = 30, h = rows.length * rowH + 30, x0 = 110, x1 = w - 70;
		const lx = function (v) { return x0 + (Math.log10(Math.max(v, 1)) / 5) * (x1 - x0); };
		const svg = el("svg", { viewBox: "0 0 " + w + " " + h, role: "img", "aria-label": label });
		[1, 10, 100, 1000, 10000, 100000].forEach(function (t) {
			svg.appendChild(el("line", { x1: lx(t), y1: 4, x2: lx(t), y2: h - 22, class: "lab-grid" }));
			svg.appendChild(el("text", { x: lx(t), y: h - 6, class: "lab-axis", "text-anchor": "middle" }, us(t)));
		});
		rows.forEach(function (r, i) {
			const y = 6 + i * rowH;
			svg.appendChild(el("text", { x: 8, y: y + 16, class: "lab-label" }, r.name));
			svg.appendChild(el("rect", { x: x0, y: y, width: Math.max(2, lx(r.value) - x0), height: 20, rx: 3, class: r.cls || "lab-bar" }));
			svg.appendChild(el("text", { x: lx(r.value) + 6, y: y + 15, class: "lab-value" }, us(r.value)));
		});
		container.replaceChildren(svg);
	}

	return { rng: rng, percentiles: percentiles, us: us, el: el, ladder: ladder };
})();
