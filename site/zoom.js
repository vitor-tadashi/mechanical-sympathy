// zoom.js - open any diagram of the page full size, with a pause button.
// The SVG is fetched from this site and placed inline, inside a shadow root so that its
// styles stay inside it, and its CSS animations can be paused.
// No dependencies, nothing loaded from another origin.
"use strict";

(function () {
	const dialog = document.createElement("dialog");
	dialog.className = "zoom";
	dialog.setAttribute("aria-label", "Diagram");
	dialog.innerHTML =
		'<div class="zoom-bar">' +
		'<h2 class="zoom-title"></h2>' +
		'<button type="button" class="btn secondary zoom-pause" aria-pressed="false">Pause</button>' +
		'<button type="button" class="btn secondary zoom-close">Close</button>' +
		"</div>" +
		'<div class="zoom-art figure"></div>' +
		'<p class="zoom-desc small"></p>' +
		'<p class="zoom-pages small"></p>';
	document.body.appendChild(dialog);

	const art = dialog.querySelector(".zoom-art");
	const pause = dialog.querySelector(".zoom-pause");
	const repo = "https://github.com/vitor-tadashi/mechanical-sympathy/blob/main/";
	let pausedStyle = null;

	function pageName(path) {
		const file = path.split("/").pop().replace(/\.md$/, "");
		if (path.startsWith("guides/")) return "Guide " + file.slice(0, 2);
		if (path.startsWith("concepts/")) return "Concept: " + file.replace(/-/g, " ");
		if (path.startsWith("examples/use-cases/")) return "Use case " + Number(file.slice(0, 2));
		return file;
	}

	async function open(src, fallbackTitle, pages) {
		art.textContent = "Loading…";
		pausedStyle = null;
		pause.textContent = "Pause";
		pause.setAttribute("aria-pressed", "false");
		dialog.querySelector(".zoom-title").textContent = fallbackTitle || "";
		dialog.querySelector(".zoom-desc").textContent = "";
		const list = dialog.querySelector(".zoom-pages");
		list.textContent = "";
		if (pages && pages.length) {
			list.append("Used in: ");
			pages.forEach(function (p, i) {
				const a = document.createElement("a");
				a.href = repo + p;
				a.textContent = pageName(p);
				list.append(i ? ", " : "", a);
			});
		}
		dialog.showModal();
		try {
			const response = await fetch(src);
			if (!response.ok) throw new Error(String(response.status));
			const doc = new DOMParser().parseFromString(await response.text(), "image/svg+xml");
			const svg = doc.documentElement;
			if (svg.nodeName !== "svg") throw new Error("not an SVG");
			svg.removeAttribute("width");
			svg.removeAttribute("height");
			const title = svg.querySelector("title");
			const desc = svg.querySelector("desc");
			if (title) dialog.querySelector(".zoom-title").textContent = title.textContent;
			if (desc) dialog.querySelector(".zoom-desc").textContent = desc.textContent;
			const host = document.createElement("div");
			const shadow = host.attachShadow({ mode: "open" });
			shadow.innerHTML =
				"<style>svg { display: block; width: 100%; height: auto; }</style>" +
				'<style media="not all">* { animation-play-state: paused !important; }</style>';
			pausedStyle = shadow.querySelectorAll("style")[1];
			shadow.appendChild(document.importNode(svg, true));
			art.replaceChildren(host);
		} catch (err) {
			art.textContent = "The diagram could not be loaded (" + err.message + ").";
		}
	}

	pause.addEventListener("click", function () {
		if (!pausedStyle) return;
		const paused = pausedStyle.media !== "all";
		pausedStyle.media = paused ? "all" : "not all";
		pause.textContent = paused ? "Play" : "Pause";
		pause.setAttribute("aria-pressed", String(paused));
	});
	dialog.querySelector(".zoom-close").addEventListener("click", function () { dialog.close(); });
	dialog.addEventListener("click", function (e) { if (e.target === dialog) dialog.close(); });

	window.zoomDiagram = open;

	// Every diagram already on the page becomes a button that opens it.
	document.querySelectorAll('.figure img[src$=".svg"]').forEach(function (img) {
		const button = document.createElement("button");
		button.type = "button";
		button.className = "zoom-trigger";
		button.setAttribute("aria-label", "Open the diagram full size: " + img.alt);
		img.replaceWith(button);
		button.appendChild(img);
		button.addEventListener("click", function () { open(img.getAttribute("src"), "", null); });
	});
})();
