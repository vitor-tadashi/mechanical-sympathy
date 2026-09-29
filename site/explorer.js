'use strict';

/* explorer.js - the DOM side of the CPU layout explorer. The rules live in layout.js. */
(function () {
	const $ = (id) => document.getElementById(id);
	const L = window.Layout;

	const el = {
		presets: $('presets'),
		sockets: $('sockets'),
		cores: $('cores'),
		ht: $('ht'),
		numbering: $('numbering'),
		nic: $('nic'),
		threads: $('threads'),
		spares: $('spares'),
		paste: $('paste'),
		pasteBox: $('paste-box'),
		generated: $('generated-fields'),
		error: $('error'),
		map: $('map'),
		out: $('out'),
		copy: $('copy'),
	};

	const LABEL = {
		thread: 'thread',
		spare: 'spare',
		sibling: 'idle sibling',
		irq: 'NIC IRQ',
		'irq-sibling': 'housekeeping',
		workqueue: 'workqueue',
		agents: 'agents',
		os: 'OS',
	};

	const int = (input, fallback) => {
		const n = parseInt(input.value, 10);
		return Number.isFinite(n) ? n : fallback;
	};

	function fillNicOptions(nodes, keep) {
		el.nic.textContent = '';
		nodes.forEach((n) => {
			const o = document.createElement('option');
			o.value = String(n);
			o.textContent = 'node ' + n;
			el.nic.appendChild(o);
		});
		el.nic.value = String(nodes.includes(keep) ? keep : nodes[0]);
	}

	const range = (count) => Array.from({ length: count }, (_, i) => i);

	function currentTopologyText() {
		if (el.paste.checked) {
			return el.pasteBox.value;
		}
		return L.generateTopology({
			sockets: Math.max(1, int(el.sockets, 1)),
			coresPerSocket: Math.max(1, int(el.cores, 1)),
			ht: el.ht.checked,
			numbering: el.numbering.value,
		});
	}

	function render() {
		el.generated.classList.toggle('hidden', el.paste.checked);
		el.pasteBox.parentElement.classList.toggle('hidden', !el.paste.checked);
		const cpus = L.parseTopology(currentTopologyText());
		if (el.paste.checked) {
			const nodes = Array.from(new Set(cpus.map((c) => c.node))).sort((a, b) => a - b);
			const shown = Array.from(el.nic.options).map((o) => o.value).join(',');
			if (nodes.length > 0 && nodes.join(',') !== shown) {
				fillNicOptions(nodes, int(el.nic, 0));
			}
		}
		const result = L.propose(cpus, {
			nic: int(el.nic, 0),
			threads: int(el.threads, 1),
			spares: Math.max(0, int(el.spares, 0)),
		});
		el.map.textContent = '';
		if (!result.ok) {
			el.error.textContent = 'Cannot propose a layout: ' + result.error + '.';
			el.error.classList.remove('hidden');
			el.out.textContent = '';
			el.copy.disabled = true;
			return;
		}
		el.error.classList.add('hidden');
		el.copy.disabled = false;
		el.out.textContent = result.text;
		drawMap(result.data);
	}

	function drawMap(data) {
		const nodes = new Map();
		data.cpus.forEach((c) => {
			if (!nodes.has(c.node)) {
				nodes.set(c.node, []);
			}
			nodes.get(c.node).push(c);
		});
		Array.from(nodes.keys()).sort((a, b) => a - b).forEach((node) => {
			const box = document.createElement('div');
			box.className = 'node';
			const h = document.createElement('h3');
			h.textContent = 'NUMA node ' + node + (node === int(el.nic, 0) ? ' (critical NIC)' : '');
			box.appendChild(h);
			const grid = document.createElement('div');
			grid.className = 'cpus';
			nodes.get(node).forEach((c) => {
				const role = data.role.get(c.cpu);
				const cell = document.createElement('div');
				cell.className = 'cpu ' + role;
				const n = document.createElement('b');
				n.textContent = 'CPU ' + c.cpu;
				const r = document.createElement('span');
				r.textContent = LABEL[role];
				cell.append(n, r);
				grid.appendChild(cell);
			});
			box.appendChild(grid);
			el.map.appendChild(box);
		});
	}

	function applyPreset(name) {
		const p = L.presets[name];
		el.paste.checked = false;
		el.sockets.value = p.sockets;
		el.cores.value = p.coresPerSocket;
		el.ht.checked = p.ht;
		el.numbering.value = p.numbering;
		fillNicOptions(range(p.sockets), p.nic);
		el.threads.value = p.threads;
		el.spares.value = p.spares;
		render();
	}

	Object.keys(L.presets).forEach((name) => {
		const b = document.createElement('button');
		b.type = 'button';
		b.className = 'btn secondary';
		b.textContent = L.presets[name].label;
		b.addEventListener('click', () => applyPreset(name));
		el.presets.appendChild(b);
	});

	el.sockets.addEventListener('input', () => {
		fillNicOptions(range(Math.max(1, int(el.sockets, 1))), int(el.nic, 0));
		render();
	});
	[el.cores, el.ht, el.numbering, el.nic, el.threads, el.spares, el.paste, el.pasteBox].forEach((input) => {
		input.addEventListener('input', render);
		input.addEventListener('change', render);
	});

	el.copy.addEventListener('click', () => {
		const done = () => {
			el.copy.textContent = 'Copied';
			setTimeout(() => { el.copy.textContent = 'Copy'; }, 1500);
		};
		if (navigator.clipboard && navigator.clipboard.writeText) {
			navigator.clipboard.writeText(el.out.textContent).then(done, () => {});
			return;
		}
		const selection = document.createRange();
		selection.selectNodeContents(el.out);
		const sel = window.getSelection();
		sel.removeAllRanges();
		sel.addRange(selection);
	});

	applyPreset('reference-2x16-ht-off');
}());
