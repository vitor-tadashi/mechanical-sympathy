// labs-core.js - "Quiet the core": one CPU runs one busy thread for one second. Each setting
// removes one kind of interruption, and the percentile ladder shows what that does to the tail.
// The costs are the orders of magnitude of the guides, not measurements.
"use strict";

(function () {
	const root = document.getElementById("lab-core");
	if (!root) return;
	const SECOND = 1e6; // µs
	const MESSAGES = 50000;
	const HANDLER = 2; // µs with warm caches

	// Each source: what removes it, how often it fires per second, how long each event lasts.
	const sources = [
		{ id: "tasks", name: "other tasks", fix: "isol", rate: 20, min: 500, max: 3000, cold: 6, cls: "ev-task" },
		{ id: "tick", name: "scheduler tick", fix: "nohz", rate: 1000, min: 1, max: 5, cls: "ev-tick" },
		{ id: "rcu", name: "RCU callbacks", fix: "rcu", rate: 5, min: 20, max: 300, cls: "ev-rcu" },
		{ id: "irq", name: "NIC interrupts", fix: "irq", rate: 200, min: 2, max: 20, cls: "ev-irq" },
		{ id: "smi", name: "SMIs", fix: "smi", rate: 1, min: 50, max: 300, cls: "ev-smi" },
	];

	function settings() {
		const s = {};
		root.querySelectorAll("input[type=checkbox]").forEach(function (c) { s[c.name] = c.checked; });
		return s;
	}

	function active(src, s) {
		if (src.id === "rcu") return !(s.rcu || s.nohz); // nohz_full also offloads RCU callbacks
		if (src.id === "tick") return true; // a residual tick stays with nohz_full
		return !s[src.fix];
	}

	function simulate(s) {
		const rand = Labs.rng(7);
		const events = [];
		for (const src of sources) {
			if (!active(src, s)) continue;
			const rate = src.id === "tick" && s.nohz ? 1 : src.rate;
			for (let t = rand() * SECOND / rate; t < SECOND; t += SECOND / rate * (0.5 + rand())) {
				events.push({ start: t, end: t + src.min + rand() * (src.max - src.min), src: src });
			}
		}
		events.sort(function (a, b) { return a.start - b.start; });
		const arrivals = [];
		for (let i = 0; i < MESSAGES; i++) arrivals.push(rand() * SECOND);
		arrivals.sort(function (a, b) { return a - b; });
		const lat = new Float64Array(MESSAGES);
		let e = 0, coldUntil = -1;
		for (let i = 0; i < MESSAGES; i++) {
			const t = arrivals[i];
			while (e < events.length && events[e].end < t) {
				if (events[e].src.cold) coldUntil = events[e].end + 50; // caches refill for a while
				e++;
			}
			let wait = 0;
			if (e < events.length && events[e].start <= t) {
				wait = events[e].end - t;
				if (events[e].src.cold) coldUntil = events[e].end + 50;
			}
			let work = HANDLER;
			if (!s.ht) work *= 1.1 + rand() * 0.5; // a busy SMT sibling shares the core
			if (t + wait < coldUntil) work *= 10; // cold caches after another task ran
			lat[i] = wait + work;
		}
		return { events: events, stats: Labs.percentiles(lat) };
	}

	function timeline(events) {
		const box = root.querySelector(".lab-timeline");
		const w = 640, h = 46, el = Labs.el;
		const svg = el("svg", { viewBox: "0 0 " + w + " " + h, role: "img", "aria-label": "One second of CPU 5, with every interruption marked" });
		svg.appendChild(el("rect", { x: 0, y: 8, width: w, height: 24, rx: 4, class: "lab-run" }));
		for (const ev of events) {
			const x = ev.start / SECOND * w;
			svg.appendChild(el("rect", { x: x, y: 4, width: Math.max(1, (ev.end - ev.start) / SECOND * w), height: 32, class: ev.src.cls }));
		}
		svg.appendChild(el("text", { x: 0, y: 46, class: "lab-axis" }, "0"));
		svg.appendChild(el("text", { x: w, y: 46, class: "lab-axis", "text-anchor": "end" }, "1 s"));
		box.replaceChildren(svg);
	}

	function update() {
		const s = settings();
		const r = simulate(s);
		timeline(r.events);
		const st = r.stats;
		Labs.ladder(root.querySelector(".lab-ladder"), [
			{ name: "p50", value: st.p50 },
			{ name: "p99", value: st.p99 },
			{ name: "p99.9", value: st.p999, cls: "lab-bar warnbar" },
			{ name: "max", value: st.max, cls: "lab-bar warnbar" },
		], "Latency percentiles of 50,000 messages");
		const left = sources.filter(function (src) { return active(src, s) && !(src.id === "tick" && s.nohz); }).map(function (src) { return src.name; });
		if (!s.ht) left.push("a busy SMT sibling");
		root.querySelector(".lab-verdict").textContent = left.length
			? "Still interrupting the thread: " + left.join(", ") + "."
			: "Only the residual tick is left: the thread has the CPU to itself.";
		root.querySelector(".lab-hint").textContent = s.nohz && !s.rcu
			? "nohz_full already moves the RCU callbacks; rcu_nocbs states it explicitly."
			: "";
	}

	root.addEventListener("change", update);
	update();
})();
