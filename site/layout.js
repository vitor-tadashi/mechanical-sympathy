'use strict';

/*
 * layout.js - the CPU layout rules of Guide 02 section 3, without any DOM.
 *
 * It is a port of the awk program inside scripts/plan-layout, and it prints the same text.
 * tools/check-explorer feeds it the fixtures in scripts/fixtures and compares the result
 * with the golden files that tools/check-plan-layout uses for the shell script.
 *
 * Not proven in production: the proposal is a starting point that applies the rules
 * mechanically. Review it against the application's thread roles.
 */
(function (root, factory) {
	if (typeof module === 'object' && module.exports) {
		module.exports = factory();
	} else {
		root.Layout = factory();
	}
}(typeof self !== 'undefined' ? self : this, function () {

	const byNumber = (a, b) => a - b;

	/** Parse `lscpu -e=CPU,NODE,SOCKET,CORE`. Rows that do not start with a number are skipped. */
	function parseTopology(text) {
		const cpus = [];
		text.split(/\r?\n/).forEach((line) => {
			const f = line.trim().split(/\s+/);
			if (!/^\d+$/.test(f[0])) {
				return;
			}
			cpus.push({
				cpu: Number(f[0]),
				node: /^\d+$/.test(f[1] || '') ? Number(f[1]) : 0,
				socket: f[2] === undefined ? '' : f[2],
				core: Number(f[3]) || 0,
			});
		});
		cpus.sort((a, b) => a.cpu - b.cpu);
		return cpus;
	}

	function summarize(cpus) {
		const sockets = new Set();
		const nodes = new Set();
		const cores = new Map();
		cpus.forEach((c) => {
			sockets.add(c.socket);
			nodes.add(c.node);
			if (!cores.has(c.core)) {
				cores.set(c.core, { id: c.core, node: c.node, cpus: [] });
			}
			cores.get(c.core).cpus.push(c.cpu);
		});
		let ht = false;
		cores.forEach((core) => {
			core.cpus.sort(byNumber);
			core.min = core.cpus[0];
			if (core.cpus.length > 1) {
				ht = true;
			}
		});
		return { sockets: sockets.size, nodes, cores, ht };
	}

	/**
	 * Propose a layout. opts: { nic, threads, spares }.
	 * Returns { ok: true, text, data } or { ok: false, error }.
	 */
	function propose(cpus, opts) {
		const nic = opts.nic;
		const threads = opts.threads;
		const spares = opts.spares;
		if (cpus.length === 0) {
			return { ok: false, error: 'no CPU rows found in the topology' };
		}
		const s = summarize(cpus);
		if (!s.nodes.has(nic)) {
			return { ok: false, error: 'NUMA node ' + nic + ' is not in the topology' };
		}
		const cpuOf = new Map(cpus.map((c) => [c.cpu, c]));

		// cores of the NIC's node, ordered by their lowest CPU
		const nodeCores = [];
		s.cores.forEach((core) => {
			if (core.node === nic) {
				nodeCores.push(core);
			}
		});
		nodeCores.sort((a, b) => a.min - b.min);

		// housekeeping core: the core of CPU 0 if it is on this node, else the first core
		let hkCore = nodeCores[0].id;
		if (cpuOf.has(0) && cpuOf.get(0).node === nic) {
			hkCore = cpuOf.get(0).core;
		}
		const avail = nodeCores.length - 1;
		const need = threads + spares;
		if (threads < 1) {
			return { ok: false, error: '--threads must be at least 1' };
		}
		if (avail < need) {
			return {
				ok: false,
				error: 'NUMA node ' + nic + ' has ' + avail + ' core(s) besides the housekeeping core, and ' +
					need + ' are needed (' + threads + ' threads + ' + spares + ' spare)',
			};
		}

		// With a second node, the whole NIC node except the housekeeping core is isolated and
		// the other node runs the OS. On a single node, only the cores that are needed are.
		const isoCore = new Set();
		nodeCores.forEach((core) => {
			if (core.id === hkCore) {
				return;
			}
			if (s.nodes.size > 1 || isoCore.size < need) {
				isoCore.add(core.id);
			}
		});
		const chosen = isoCore.size;

		const isolated = [];
		const os = [];
		cpus.forEach((c) => {
			(isoCore.has(c.core) ? isolated : os).push(c.cpu);
		});
		const hkCpus = cpus.filter((c) => c.core === hkCore).map((c) => c.cpu);
		const irq = hkCpus[0];

		// OS cores outside the housekeeping core, ordered by their lowest CPU. Roles go to whole
		// cores, so that Hyper-Threading siblings never split between two of them.
		const seenCore = new Set();
		const osCores = [];
		os.forEach((cpu) => {
			const core = cpuOf.get(cpu).core;
			if (core === hkCore || seenCore.has(core)) {
				return;
			}
			seenCore.add(core);
			osCores.push(core);
		});
		if (osCores.length < 3) {
			return {
				ok: false,
				error: 'only ' + osCores.length + ' OS core(s) outside the housekeeping core, ' +
					'at least 3 are needed for workqueues and agents',
			};
		}
		const wqCores = new Set(osCores.slice(0, 2));
		const agentCores = new Set(osCores.slice(2, 4));
		const wq = os.filter((cpu) => wqCores.has(cpuOf.get(cpu).core));
		const agents = os.filter((cpu) => agentCores.has(cpuOf.get(cpu).core));
		const spare = chosen - threads;

		const list = (a, sep) => a.join(sep);
		const lines = [
			'# plan-layout: proposed CPU layout',
			'# host: ' + s.sockets + ' socket(s), ' + s.nodes.size + ' NUMA node(s), ' + cpus.length + ' CPUs, ' +
				s.cores.size + ' cores, Hyper-Threading ' + (s.ht ? 'on' : 'off'),
			'# critical NIC on node ' + nic + ', critical threads: ' + threads,
			'# node ' + nic + ': housekeeping core ' + hkCore + ' (CPUs ' + list(hkCpus, ',') + '), isolated cores: ' +
				chosen + ' (needed ' + threads + ', spare ' + spare + ')',
			'ISOLATED_CPUS=(' + list(isolated, ' ') + ')',
			'OS_CPUS=(' + list(os, ' ') + ')',
			'WORKQUEUE_CPUS=(' + list(wq, ' ') + ')',
			'HOUSEKEEPING_PIN_CPUS=(' + agents[0] + ')',
			'HOUSEKEEPING_SLICE_CPUS=(' + list(agents, ' ') + ')',
			'# critical NIC irq_cpus (third field of its NICS entry): ' + irq,
			'# kernel arguments (Guide 01): isolcpus=' + list(isolated, ',') + ' nohz_full=' + list(isolated, ',') +
				' rcu_nocbs=' + list(isolated, ','),
		];

		// Roles for the picture: the lowest CPU of each isolated core takes a thread or stays spare,
		// and the other siblings of an isolated core stay idle.
		const isolatedCores = nodeCores.filter((core) => isoCore.has(core.id));
		const role = new Map();
		isolatedCores.forEach((core, i) => {
			core.cpus.forEach((cpu, k) => {
				role.set(cpu, k > 0 ? 'sibling' : (i < threads ? 'thread' : 'spare'));
			});
		});
		hkCpus.forEach((cpu) => role.set(cpu, cpu === irq ? 'irq' : 'irq-sibling'));
		wq.forEach((cpu) => role.set(cpu, 'workqueue'));
		agents.forEach((cpu) => role.set(cpu, 'agents'));
		os.forEach((cpu) => {
			if (!role.has(cpu)) {
				role.set(cpu, 'os');
			}
		});

		return {
			ok: true,
			text: lines.join('\n'),
			data: { cpus, isolated, os, wq, agents, irq, hkCore, hkCpus, chosen, spare, ht: s.ht, role },
		};
	}

	/**
	 * Generate a topology in the format of `lscpu -e=CPU,NODE,SOCKET,CORE`.
	 * numbering: 'round-robin' (CPU n on socket n % sockets, like the reference host) or
	 * 'socket-by-socket' (the first cores of a socket are numbered together, siblings last).
	 */
	function generateTopology(p) {
		const cores = p.sockets * p.coresPerSocket;
		const perCore = p.ht ? 2 : 1;
		const rows = [];
		for (let c = 0; c < cores * perCore; c++) {
			const idx = c % cores;
			const socket = p.numbering === 'round-robin' ? idx % p.sockets : Math.floor(idx / p.coresPerSocket);
			rows.push([c, socket, socket, idx]);
		}
		const pad = (n, w) => String(n).padStart(w, ' ');
		const out = ['CPU NODE SOCKET CORE'];
		rows.forEach((r) => out.push(pad(r[0], 3) + ' ' + pad(r[1], 4) + ' ' + pad(r[2], 6) + ' ' + pad(r[3], 4)));
		return out.join('\n') + '\n';
	}

	/**
	 * The three hosts of scripts/fixtures, as explorer presets. The key is the fixture name.
	 * tools/check-explorer checks that each preset generates its fixture and proposes its golden.
	 */
	const presets = {
		'reference-2x16-ht-off': {
			label: 'Reference host: 2 x 16 cores, no Hyper-Threading',
			sockets: 2, coresPerSocket: 16, ht: false, numbering: 'round-robin', nic: 1, threads: 6, spares: 2,
		},
		'desktop-1x8-ht-on': {
			label: 'Small host: 1 x 8 cores, Hyper-Threading',
			sockets: 1, coresPerSocket: 8, ht: true, numbering: 'socket-by-socket', nic: 0, threads: 3, spares: 1,
		},
		'server-2x12-ht-on': {
			label: 'Server: 2 x 12 cores, Hyper-Threading',
			sockets: 2, coresPerSocket: 12, ht: true, numbering: 'socket-by-socket', nic: 1, threads: 4, spares: 2,
		},
	};

	return { parseTopology, propose, generateTopology, presets };
}));
