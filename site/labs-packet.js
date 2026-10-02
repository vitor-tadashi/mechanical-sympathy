// labs-packet.js - "Life of a packet": the steps between the wire and the application, and what
// each setting adds or removes. The costs are the orders of magnitude of the guides, for the
// first packet after a quiet moment, not measurements.
"use strict";

(function () {
	const root = document.getElementById("lab-packet");
	if (!root) return;

	function value(name) { return root.querySelector('[name="' + name + '"]').value; }
	function checked(name) { return root.querySelector('[name="' + name + '"]').checked; }

	function steps() {
		const path = value("path");
		const deep = checked("deep");
		if (path === "bypass") {
			return [
				{ name: "NIC writes the packet (DMA)", us: 0.5, cls: "st-hk" },
				{ name: "pinned thread polls the ring", us: 0.3, cls: "st-app" },
				{ name: "user-space stack", us: 0.5, cls: "st-app" },
			];
		}
		const out = [{ name: "NIC writes the packet (DMA)", us: 0.5, cls: "st-hk" }];
		const co = value("coalescing");
		if (co === "adaptive") out.push({ name: "adaptive coalescing timer", us: 40, cls: "st-wait" });
		if (co === "fixed") out.push({ name: "rx-usecs 50 timer", us: 50, cls: "st-wait" });
		const onApp = value("irq") === "isolated";
		const blocks = value("reader") === "block";
		// A CPU sleeps between packets unless a thread spins on it: the housekeeping CPU always
		// may, the application's CPU only when its reader blocks.
		if (deep && (!onApp || blocks)) out.push({ name: "the interrupted CPU leaves a deep C-state", us: 30, cls: "st-wait" });
		out.push({ name: onApp ? "hard IRQ, on the application's CPU" : "hard IRQ", us: 1.5, cls: onApp ? "st-wait" : "st-hk" });
		out.push({ name: onApp ? "softirq, on the application's CPU" : "softirq: NAPI, IP, UDP", us: 2.5, cls: onApp ? "st-wait" : "st-hk" });
		if (blocks) {
			out.push({ name: onApp ? "scheduler switches to the reader" : "wake-up IPI and scheduler", us: onApp ? 5 : 10, cls: "st-wait" });
			if (deep && !onApp) out.push({ name: "reader's CPU leaves a deep C-state", us: 30, cls: "st-wait" });
		} else {
			out.push({ name: "spinning reader sees it", us: onApp ? 0.1 : 0.3, cls: "st-app" });
		}
		out.push({ name: "recv() copies it", us: 0.2, cls: "st-app" });
		return out;
	}

	function render() {
		const list = steps();
		const total = list.reduce(function (a, s) { return a + s.us; }, 0);
		const bar = root.querySelector(".lab-path");
		bar.replaceChildren();
		const scale = Math.max(total, 10);
		for (const s of list) {
			const seg = document.createElement("div");
			seg.className = "seg " + s.cls;
			seg.style.flexGrow = String(s.us / scale);
			seg.title = s.name + ": " + Labs.us(s.us);
			bar.appendChild(seg);
		}
		const rest = document.createElement("div");
		rest.className = "seg seg-rest";
		rest.style.flexGrow = String(Math.max(0, (scale - total) / scale));
		bar.appendChild(rest);

		const tok = root.querySelector(".lab-token");
		tok.style.animation = "none";
		void tok.offsetWidth;
		tok.style.setProperty("--trip", (total / scale * 100).toFixed(1) + "%");
		tok.style.animation = "";

		const table = root.querySelector(".lab-steps");
		table.replaceChildren();
		for (const s of list) {
			const tr = document.createElement("tr");
			const a = document.createElement("td"); a.innerHTML = '<span class="dot ' + s.cls + '"></span>';
			a.append(" " + s.name);
			const b = document.createElement("td"); b.textContent = Labs.us(s.us);
			tr.append(a, b);
			table.appendChild(tr);
		}
		root.querySelector(".lab-total").textContent = Labs.us(total);
		const notes = [];
		if (value("irq") === "isolated" && value("path") === "kernel") notes.push("The interrupt and the softirq run on the application's own CPU: every packet stops the spinning thread first.");
		if (value("coalescing") !== "zero" && value("path") === "kernel") notes.push("The first packet after a quiet moment pays the whole coalescing timer.");
		if (value("reader") === "block" && value("path") === "kernel") notes.push("A blocked reader must be woken through the kernel.");
		if (checked("deep")) notes.push("Deep C-states add an exit on every CPU that was asleep.");
		if (!notes.length) notes.push(value("path") === "bypass" ? "No interrupt, no softirq, no system call: the application reads the NIC's ring itself." : "This is the tuned kernel path of Guide 04: what is left is the stack's own work.");
		root.querySelector(".lab-notes").textContent = notes.join(" ");
		root.querySelectorAll(".kernel-only").forEach(function (n) { n.disabled = value("path") === "bypass"; });
	}

	root.addEventListener("change", render);
	render();
})();
