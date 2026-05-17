# ───────────────────────────────────────────────────────
# InsureDAO — Makefile
# ───────────────────────────────────────────────────────

-include .env

FORGE := $(HOME)/.foundry/bin/forge

.PHONY: build test clean fmt lint slither coverage gas-snapshot deploy-arbitrum verify-deployment

# ─── Build & Test ──────────────────────────────────────

build:
	$(FORGE) build --sizes

test:
	$(FORGE) test -vvv

clean:
	$(FORGE) clean

fmt:
	$(FORGE) fmt

fmt-check:
	$(FORGE) fmt --check

# ─── Deployment (Arbitrum Sepolia) ─────────────────────

deploy-arbitrum:
	$(FORGE) script script/DeployAll.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC) \
	  --broadcast --verify --etherscan-api-key $(ARBISCAN_API_KEY) -vvvv

verify-deployment:
	$(FORGE) script script/VerifyDeployment.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC) -vvvv

upgrade-v2:
	$(FORGE) script script/UpgradeAndFund.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC) \
	  --broadcast --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 -vvvv

seed-tokens:
	@test -n "$(WALLET)" || (echo "Usage: make seed-tokens WALLET=0xYourAddress" && exit 1)
	SEED_WALLET=$(WALLET) $(FORGE) script script/SeedTestTokens.s.sol \
	  --rpc-url $(ARBITRUM_SEPOLIA_RPC) --broadcast -vvvv

# ─── Gas & Coverage ───────────────────────────────────

gas-snapshot:
	$(FORGE) snapshot --snap .gas-snapshot

gas-report:
	$(FORGE) test --match-contract GasSnapshot -vv

coverage:
	$(FORGE) coverage --report lcov --report-file reports/coverage.lcov
	@echo "Coverage LCOV written to reports/coverage.lcov"
	@command -v genhtml >/dev/null 2>&1 && genhtml reports/coverage.lcov -o reports/coverage-html \
	  && echo "HTML report: reports/coverage-html/index.html" \
	  || echo "Install lcov (apt install lcov) for HTML report"

# ─── Security ─────────────────────────────────────────

slither:
	slither . --config-file .slither.config.json 2>&1 | tee reports/slither-output.txt
