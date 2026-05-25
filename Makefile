.DEFAULT_GOAL := help

.PHONY: help all clean compile compile-cache lint smoke scoreboard random-scoreboard block-tests parameter-compile check verify

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
	@printf "  make smoke    Build and run the top-level directed smoke test\n"
	@printf "  make scoreboard  Run the self-checking cache scoreboard test\n"
	@printf "  make random-scoreboard  Run seeded random scoreboard parameter cases\n"
	@printf "  make block-tests  Run block-level self-checking tests\n"
	@printf "  make parameter-compile  Compile selected non-default parameter configurations\n"
	@printf "  make check    Run compile, lint, and smoke\n"
	@printf "  make verify   Run check, scoreboard, and parameter compile sweep\n"
	@printf "  make clean    Remove generated simulation outputs\n\n"

all: check

compile:
	$(call RUN_WITH_STATUS,COMPILE,./scripts/compile_rtl.sh)

compile-cache:
	$(call RUN_WITH_STATUS,COMPILE-CACHE,./scripts/compile_cache.sh)

lint:
	$(call RUN_WITH_STATUS,LINT,./scripts/lint_rtl.sh)

smoke:
	$(call RUN_WITH_STATUS,SMOKE,./scripts/run_top_tb.sh)

scoreboard:
	$(call RUN_WITH_STATUS,SCOREBOARD,./scripts/run_scoreboard_tb.sh)

random-scoreboard:
	$(call RUN_WITH_STATUS,RANDOM-SCOREBOARD,./scripts/run_random_scoreboard_tb.py)

block-tests:
	$(call RUN_WITH_STATUS,BLOCK-TESTS,./scripts/run_block_tb.sh)

parameter-compile:
	$(call RUN_WITH_STATUS,PARAMETER-COMPILE,./scripts/run_parameter_compile_sweep.sh)

check:
	$(call RUN_WITH_STATUS,CHECK,$(MAKE) --no-print-directory compile lint smoke)

verify:
	$(call RUN_WITH_STATUS,VERIFY,$(MAKE) --no-print-directory check scoreboard random-scoreboard block-tests parameter-compile)

clean:
	$(call RUN_WITH_STATUS,CLEAN,$(RM) -r sim/build obj_dir *.vcd *.fst)
