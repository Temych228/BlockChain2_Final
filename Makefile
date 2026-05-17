# ───────────────────────────────────────────────────────
# InsureDAO — Makefile
# ───────────────────────────────────────────────────────

-include .env

.PHONY: build test clean fmt lint slither coverage gas-snapshot deploy-arbitrum verify-deployment

# ─── Build & Test ──────────────────────────────────────

build:
	forge build --sizes

test:
	forge test -vvv

clean:
	forge clean

fmt:
	forge fmt

fmt-check:
	forge fmt --check

# ─── Deployment (Arbitrum Sepolia) ─────────────────────

deploy-arbitrum:
	forge script script/DeployAll.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC) \
	  --broadcast --verify --etherscan-api-key $(ARBISCAN_API_KEY) -vvvv

verify-deployment:
	forge script script/VerifyDeployment.s.sol --rpc-url $(ARBITRUM_SEPOLIA_RPC) -vvvv

# ─── Gas & Coverage ───────────────────────────────────

gas-snapshot:
	forge snapshot --snap .gas-snapshot

gas-report:
	forge test --match-contract GasSnapshot -vv

coverage:
	forge coverage --report lcov --report-file reports/coverage.lcov
	@echo "Coverage LCOV written to reports/coverage.lcov"
	@command -v genhtml >/dev/null 2>&1 && genhtml reports/coverage.lcov -o reports/coverage-html \
	  && echo "HTML report: reports/coverage-html/index.html" \
	  || echo "Install lcov (apt install lcov) for HTML report"

# ─── Security ─────────────────────────────────────────

slither:
	slither . --config-file .slither.config.json 2>&1 | tee reports/slither-output.txt
