.PHONY: lint
lint:
	@ct lint --all --lint-conf=lintconf.yaml

.PHONY: ct
ct:
	@ct install --all

.PHONY: test
test: lint ct