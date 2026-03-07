EMACS ?= emacs

EL_FILES := $(wildcard sysml2-*.el)
ELC_FILES := $(EL_FILES:.el=.elc)

TEST_FILES := test/test-helper.el test/test-lang.el test/test-font-lock.el \
	test/test-indent.el test/test-completion.el test/test-navigation.el \
	test/test-plantuml.el test/test-diagram.el test/test-project.el \
	test/test-flymake.el test/test-outline.el test/test-fmi.el \
	test/test-cosim.el test/test-evil.el test/test-api.el test/test-ts.el

.PHONY: all test compile clean lint tree-sitter-test

all: compile test

test:
	$(EMACS) --batch -L . -L test \
	  -l sysml2-mode \
	  $(patsubst %,-l %,$(TEST_FILES)) \
	  -f ert-run-tests-batch-and-exit

compile: $(ELC_FILES)

%.elc: %.el
	$(EMACS) --batch -L . \
	  --eval "(setq byte-compile-error-on-warn t)" \
	  -f batch-byte-compile $<

clean:
	rm -f *.elc

lint:
	@for f in $(EL_FILES); do \
	  echo "Checking $$f..."; \
	  $(EMACS) --batch -L . -l $$f \
	    --eval "(checkdoc-file \"$$f\")" 2>&1 || true; \
	done

tree-sitter-test:
	cd tree-sitter-sysml && npm install && npx tree-sitter generate && npx tree-sitter test
