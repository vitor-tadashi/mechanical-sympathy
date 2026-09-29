# Quality gates for this repository. CI (.github/workflows/lint.yml) runs `make lint`.

.PHONY: help lint lint-scripts lint-docs lint-java install-git-hooks

PROBE := examples/java-latency-probe

help:
	@echo "Targets:"
	@echo "  lint               lint-scripts + lint-docs + lint-java (the gate CI enforces)"
	@echo "  lint-scripts       no .sh extensions, exec bits, ShellCheck (enable=all), bash -n, plan-layout fixtures"
	@echo "  lint-docs          Markdown links and anchors, Mermaid blocks, SVG rules, orphan SVGs, image alt text"
	@echo "  lint-java          Checkstyle + compile + dependency approval for the Java probe"
	@echo "  install-git-hooks  opt in to the pre-commit (make lint) and commit-msg (title) hooks"

lint: lint-scripts lint-docs lint-java

lint-scripts:
	./tools/lint-scripts
	./tools/check-plan-layout

lint-docs:
	./tools/lint-docs

lint-java:
	cd $(PROBE) && ./gradlew --quiet check

install-git-hooks:
	./tools/install-git-hooks
