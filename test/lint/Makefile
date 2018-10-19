VERILATOR=verilator
LINT_ARGS=--lint-only
DOTF=$(HDL)/openila.f

.PHONY: all clean lint
all: clean lint

# build filelist from project tree
srcs.mk: Makefile $(DOTF)
	$(SCRIPTS)/listfiles -r -f make $(DOTF) -o srcs.mk
-include srcs.mk

lint:
	$(VERILATOR) $(LINT_ARGS) $(patsubst %,-I%,$(INCDIRS)) $(SRCS)

clean:
	rm -f srcs.mk