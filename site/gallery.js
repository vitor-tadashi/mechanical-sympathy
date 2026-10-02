// gallery.js - list every diagram from diagrams.json (written by tools/build-site), by topic.
"use strict";

(function () {
	// The topic of a diagram comes from the first guide or concept that uses it.
	const byGuide = {
		"00": "firmware", "01": "cpu", "02": "cpu", "03": "memory", "04": "network", "05": "cpu",
		"06": "network", "07": "network", "08": "network", "09": "measure", "10": "measure",
		"11": "measure", "12": "memory",
	};
	const byConcept = {
		bootloader: "cpu", cgroups: "cpu", "clocks-and-time": "measure", "cpu-isolation": "cpu",
		ethtool: "network", "hardware-topology": "cpu", "huge-pages": "memory",
		"interrupts-and-deferred-work": "cpu", "jvm-pauses": "app", "logging-and-io": "app",
		"memory-reclaim": "memory", "network-buffers": "network", "network-tuning": "network",
		"power-and-frequency": "firmware", queueing: "measure", "security-mitigations": "cpu",
		"swap-and-oom": "memory", "tail-latency": "measure", "thread-handoff": "app",
	};
	const byUseCase = {
		"01": "cpu", "02": "cpu", "03": "cpu", "04": "network", "05": "memory", "06": "memory",
		"07": "firmware", "08": "measure", "09": "network", "10": "network", "11": "firmware",
		"12": "cpu", "13": "firmware", "14": "cpu", "15": "network", "16": "app", "17": "memory",
		"18": "cpu", "19": "measure",
	};
	// Guides and concepts name the subject best, then use cases; the README's hero is about the tail.
	function topicOf(pages) {
		for (const p of pages) {
			const m = p.match(/^guides\/(\d\d)-/);
			if (m && byGuide[m[1]]) return byGuide[m[1]];
			const c = p.match(/^concepts\/([a-z-]+)\.md$/);
			if (c && byConcept[c[1]]) return byConcept[c[1]];
		}
		for (const p of pages) {
			const u = p.match(/^examples\/use-cases\/(\d\d)-/);
			if (u && byUseCase[u[1]]) return byUseCase[u[1]];
		}
		return "measure";
	}

	const grid = document.getElementById("gallery");
	const count = document.getElementById("count");
	let items = [];

	function render(topic) {
		const shown = items.filter(function (d) { return topic === "all" || d.topic === topic; });
		grid.replaceChildren();
		for (const d of shown) {
			const card = document.createElement("article");
			card.className = "card";
			const button = document.createElement("button");
			button.type = "button";
			button.className = "zoom-trigger figure flush";
			button.setAttribute("aria-label", "Open full size: " + d.title);
			const img = document.createElement("img");
			img.src = "assets/diagrams/" + d.file;
			img.alt = d.desc || d.title;
			img.loading = "lazy";
			button.appendChild(img);
			button.addEventListener("click", function () { window.zoomDiagram(img.src, d.title, d.pages); });
			const h = document.createElement("h3");
			h.textContent = d.title;
			const meta = document.createElement("p");
			meta.className = "meta";
			meta.textContent = d.pages.length + (d.pages.length === 1 ? " page" : " pages") + (d.animated ? " · animated" : "");
			card.append(button, h, meta);
			grid.appendChild(card);
		}
		count.textContent = shown.length + " diagrams";
	}

	document.querySelectorAll(".filters button").forEach(function (b) {
		b.addEventListener("click", function () {
			document.querySelectorAll(".filters button").forEach(function (o) { o.setAttribute("aria-pressed", String(o === b)); });
			render(b.dataset.topic);
		});
	});

	fetch("diagrams.json")
		.then(function (r) { if (!r.ok) throw new Error(String(r.status)); return r.json(); })
		.then(function (list) {
			items = list.filter(function (d) { return d.pages.length > 0; }).map(function (d) {
				d.topic = topicOf(d.pages);
				return d;
			});
			render("all");
		})
		.catch(function (err) {
			count.textContent = "The list of diagrams could not be loaded (" + err.message + "). Build the site with tools/build-site.";
		});
})();
