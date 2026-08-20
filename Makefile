.DEFAULT_GOAL := help

.PHONY: help all clean compile compile-cache lint uvm-smoke uvm-scoreboard uvm-random uvm-traffic uvm-soak coverage block-tests parameter-compile check verify

define RUN_WITH_STATUS
	@status=0; \
	printf "\n%s\n" "--------------------------------------"; \
	printf "MAKE $(1) STARTED\n"; \
	printf "%s\n" "--------------------------------------"; \
	$(2) || status=$$?; \
	printf "%s\n" "--------------------------------------"; \
	printf "MAKE $(1) FINISHED\n"; \
	printf "%s\n" "--------------------------------------"; \
	if [ $$status -eq 0 ]; then \
		printf "PASSED\n"; \
	else \
		printf "FAILED\n"; \
	fi; \
	printf "%s\n\n" "--------------------------------------"; \
	exit $$status
endef

help:
	@printf "\nCache soft-IP targets\n"
	@printf "=====================\n\n"
	@printf "  make compile  Elaborate the RTL file list with Verilator\n"
	@printf "  make compile-cache  Elaborate only the reusable cache top\n"
	@printf "  make lint     Run RTL style checks and Verilator lint\n"
	@printf "  make uvm-smoke  Build and run the UVM testbench in its default configuration\n"
	@printf "  make uvm-scoreboard  Run the directed UVM configuration matrix\n"
	@printf "  make uvm-random  Run seeded random UVM parameter cases\n"
	@printf "  make uvm-traffic  Run constrained-random CPU traffic (random stimulus, fixed geometry)\n"
	@printf "  make uvm-soak  Run a long constrained-random traffic soak over six seeds\n"
	@printf "  make coverage  Build an instrumented model and report RTL and functional coverage\n"
	@printf "  make block-tests  Run block-level directed tests for the L1/L2 submodules\n"
	@printf "  make parameter-compile  Compile selected non-default parameter configurations\n"
	@printf "  make check    Run compile, lint, and the UVM smoke run\n"
	@printf "  make verify   Run check, the UVM matrix, random cases, block tests, and the compile sweep\n"
	@printf "  make clean    Remove generated simulation outputs\n\n"
	@printf "  The UVM targets need a UVM-capable Verilator (>= 5.046) and the\n"
	@printf "  Accellera uvm-core sources; point UVM_HOME at its src/ directory.\n\n"

all: check

compile:
	$(call RUN_WITH_STATUS,COMPILE,./scripts/compile_rtl.sh)

compile-cache:
	$(call RUN_WITH_STATUS,COMPILE-CACHE,./scripts/compile_cache.sh)

lint:
	$(call RUN_WITH_STATUS,LINT,./scripts/lint_rtl.sh)

uvm-smoke:
	$(call RUN_WITH_STATUS,UVM-SMOKE,./scripts/run_uvm_tb.sh default)

uvm-scoreboard:
	$(call RUN_WITH_STATUS,UVM-SCOREBOARD,./scripts/run_uvm_scoreboard.sh)

uvm-random:
	$(call RUN_WITH_STATUS,UVM-RANDOM,./scripts/run_uvm_random.py)

uvm-traffic:
	$(call RUN_WITH_STATUS,UVM-TRAFFIC,./scripts/run_traffic.sh)

# Long random run. Not part of `verify`: it takes minutes rather than seconds,
# and its value is in being run deliberately with a changed seed, not in being
# run identically on every commit.
uvm-soak:
	$(call RUN_WITH_STATUS,UVM-SOAK,TRAFFIC_OPS=4000 TRAFFIC_SEEDS="1 2 3 4 5 6" ./scripts/run_traffic.sh)

coverage:
	$(call RUN_WITH_STATUS,COVERAGE,./scripts/run_coverage.sh)

block-tests:
	$(call RUN_WITH_STATUS,BLOCK-TESTS,./scripts/run_block_tb.sh)

parameter-compile:
	$(call RUN_WITH_STATUS,PARAMETER-COMPILE,./scripts/run_parameter_compile_sweep.sh)

check:
	$(call RUN_WITH_STATUS,CHECK,$(MAKE) --no-print-directory compile lint uvm-smoke)

verify:
	$(call RUN_WITH_STATUS,VERIFY,$(MAKE) --no-print-directory check uvm-scoreboard uvm-random uvm-traffic block-tests parameter-compile)

clean:
	$(call RUN_WITH_STATUS,CLEAN,$(RM) -r sim/build obj_dir *.vcd *.fst)
