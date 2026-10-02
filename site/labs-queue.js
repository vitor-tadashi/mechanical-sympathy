// labs-queue.js - "Queueing, and the benchmark that lied": one server, random arrivals. Change the
// load and the variability of the service time, add a stall, and compare what users wait with
// what a closed-loop benchmark records. Simulated and illustrative.
"use strict";

(function () {
	const root = document.getElementById("lab-queue");
	if (!root) return;
	const S = 10; // mean service time, µs
	const DURATION = 2e6; // µs of simulated time
	const STALL = 20000, STALL_EVERY = 1e6; // a 20 ms stall once a second

	function serviceTime(kind, rand) {
		if (kind === "steady") return S;
		if (kind === "random") return -Math.log(1 - rand()) * S;
		// heavy tail: mostly fast, once in a while 20 times the mean, same average
		return rand() < 0.05 ? S * 10.5 : S * 0.5;
	}

	function inStall(t, on) {
		return on && (t % STALL_EVERY) < STALL;
	}

	function simulate(rho, kind, stall) {
		const rand = Labs.rng(11);
		const lambda = rho / S;
		const open = [];
		const queue = [];
		let t = 0, free = 0;
		while (true) {
			t += -Math.log(1 - rand()) / lambda;
			if (t > DURATION) break;
			let start = Math.max(t, free);
			if (inStall(start, stall)) start = Math.floor(start / STALL_EVERY) * STALL_EVERY + STALL;
			free = start + serviceTime(kind, rand);
			open.push(free - t);
			if (t < 200000) queue.push([t, free]);
		}
		// A closed-loop benchmark: one request at a time, the next one only after the answer.
		const closed = [];
		let c = 0;
		const r2 = Labs.rng(11);
		while (c < DURATION) {
			let start = c;
			if (inStall(start, stall)) start = Math.floor(start / STALL_EVERY) * STALL_EVERY + STALL;
			const done = start + serviceTime(kind, r2);
			closed.push(done - c);
			c = done + 1 / lambda; // it waits as long as a user would between requests
		}
		return { open: Labs.percentiles(open), closed: Labs.percentiles(closed), queue: queue };
	}

	function queueChart(q) {
		const w = 640, h = 120, el = Labs.el;
		const svg = el("svg", { viewBox: "0 0 " + w + " " + h, role: "img", "aria-label": "Requests waiting during the first 200 ms" });
		const pts = [];
		let maxQ = 1;
		for (let i = 0; i <= 400; i++) {
			const tt = i * 500;
			let n = 0;
			for (const r of q) if (r[0] <= tt && tt < r[1]) n++;
			maxQ = Math.max(maxQ, n);
			pts.push([tt, n]);
		}
		svg.appendChild(el("rect", { x: 40, y: 4, width: w - 44, height: h - 24, class: "lab-plot" }));
		const d = pts.map(function (p, i) { return (i ? "L" : "M") + (40 + p[0] / 200000 * (w - 44)).toFixed(1) + "," + (h - 20 - p[1] / maxQ * (h - 28)).toFixed(1); }).join(" ");
		svg.appendChild(el("path", { d: d, class: "lab-line" }));
		svg.appendChild(el("text", { x: 34, y: 14, class: "lab-axis", "text-anchor": "end" }, String(maxQ)));
		svg.appendChild(el("text", { x: 34, y: h - 20, class: "lab-axis", "text-anchor": "end" }, "0"));
		svg.appendChild(el("text", { x: 40, y: h - 4, class: "lab-axis" }, "0 ms"));
		svg.appendChild(el("text", { x: w, y: h - 4, class: "lab-axis", "text-anchor": "end" }, "200 ms"));
		root.querySelector(".lab-queuechart").replaceChildren(svg);
	}

	function update() {
		const rho = Number(root.querySelector('[name="rho"]').value) / 100;
		root.querySelector(".lab-rho").textContent = Math.round(rho * 100) + " %";
		const kind = root.querySelector('[name="service"]').value;
		const stall = root.querySelector('[name="stall"]').checked;
		const r = simulate(rho, kind, stall);
		queueChart(r.queue);
		Labs.ladder(root.querySelector(".lab-ladder"), [
			{ name: "users p50", value: r.open.p50 },
			{ name: "users p99", value: r.open.p99, cls: "lab-bar warnbar" },
			{ name: "users p99.9", value: r.open.p999, cls: "lab-bar warnbar" },
			{ name: "bench p99", value: r.closed.p99, cls: "lab-bar benchbar" },
			{ name: "bench p99.9", value: r.closed.p999, cls: "lab-bar benchbar" },
		], "Response time percentiles: what users wait, and what a closed-loop benchmark records");
		const gap = r.open.p999 / Math.max(r.closed.p999, 0.001);
		root.querySelector(".lab-verdict").textContent = gap > 3
			? "The closed-loop benchmark reports a p99.9 " + gap.toFixed(0) + " times better than what users get: it stops sending while the server is stuck."
			: "Users and the benchmark roughly agree here. Add the stall, or raise the load, and watch them part.";
	}

	root.addEventListener("input", update);
	update();
})();
