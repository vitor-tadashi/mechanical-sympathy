# Quality gates for this repository. CI (.github/workflows/lint.yml) runs `make lint`.

.PHONY: help lint lint-scripts lint-docs lint-site lint-java check-scripts check-script-regressions check-containers check-vm install-git-hooks site

PROBE := examples/java-latency-probe

help:
	@echo "Targets:"
	@echo "  lint               lint-scripts + lint-docs + lint-site + lint-java (the gate CI enforces)"
	@echo "  lint-scripts       no .sh extensions, exec bits, ShellCheck (enable=all), bash -n, plan-layout and size-buffers fixtures"
	@echo "  lint-docs          Markdown links and anchors, Mermaid blocks, SVG rules, orphan SVGs, image alt text, glossary order"
	@echo "  lint-site          site/ pages: no external loads, links, alt text, layout.js versus plan-layout, buffers.js versus size-buffers"
	@echo "  site               assemble _site/ for a local preview"
	@echo "  lint-java          Checkstyle + compile + dependency approval for the Java probe"
	@echo "  check-scripts      every guide script end to end on fake hosts (Linux only; see tools/check-scripts)"
	@echo "  check-containers   the guides in systemd containers of RHEL-family images (podman or docker; see tools/check-containers)"
	@echo "  check-vm           the guides on a real kernel in KVM guests of RHEL-family cloud images (Linux with KVM only; see tools/check-vm)"
	@echo "  install-git-hooks  opt in to the pre-commit (make lint) and commit-msg (title) hooks"

lint: lint-scripts lint-docs lint-site lint-java

lint-scripts:
	./tools/lint-scripts
	./tools/check-plan-layout
	./tools/check-size-buffers

lint-docs:
	./tools/lint-docs
	./tools/check-glossary

lint-site:
	./tools/lint-site

site:
	./tools/build-site

lint-java:
	cd $(PROBE) && ./gradlew --quiet check

check-scripts:
	./tools/check-scripts

check-script-regressions:
	./tools/check-script-regressions

check-containers:
	./tools/check-containers

check-vm:
	./tools/check-vm

install-git-hooks:
	./tools/install-git-hooks
