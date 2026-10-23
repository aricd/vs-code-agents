# Makefile for VS Code Agents and Skills
# 
# Quick commands for managing shared agents/skills directory

.PHONY: help setup setup-dry-run update list clean verify check-archaeology check-archaeology-sh

LINK_CONFIG         := scripts/link-config.yaml
LINK_CONFIG_EXAMPLE := scripts/link-config.example.yaml
LINK_SCRIPT         := scripts/link_setup.py
BACKUP_EXT          := .bak

# Invoke the canonical Python implementation directly rather than the .sh shim.
# The shim adds no logic (see its header), and `./scripts/link-setup.sh` forces the
# recipe's shell to resolve a relative path against Make's CWD -- which on Windows is
# a backslash path that bash consumes as escapes ("C:devmdt..."), so the shim is never
# found. Passing the script as an ARGUMENT to python avoids that resolution entirely.
# Override on a host where the interpreter is named differently: make PYTHON=python3 setup
PYTHON              ?= python

# Target workspace .github roots, parsed from the config's `target_root:` lines
# Guard against missing link-config.yaml so Make doesn't error on `make help`.
TARGET_ROOTS := $(shell [ -f $(LINK_CONFIG) ] && grep 'target_root:' $(LINK_CONFIG) | sed -e 's/.*target_root:[[:space:]]*//' -e 's/"//g' -e "s/'//g")
LINK_DIRS := $(foreach r,$(TARGET_ROOTS),$(r)/skills $(r)/agents $(r)/prompts $(r)/scripts)

help:
	@echo "VS Code Agents & Skills Management"
	@echo ""
	@echo "Usage:"
	@echo "  make setup           Set up symlinks (create/update)"
	@echo "  make setup-dry-run   Preview what will be done"
	@echo "  make update          Re-run setup (update existing symlinks)"
	@echo "  make list            List current symlinks and their targets"
	@echo "  make verify          Verify symlink integrity"
	@echo "  make clean           Remove all symlinks (but keep backups)"
	@echo "  make clean-backups   Remove backup files"
	@echo "  make check-archaeology      Check consumer-facing files for archaeological comments (pwsh)"
	@echo "  make check-archaeology-sh   Check consumer-facing files for archaeological comments (bash)"
	@echo ""
	@echo "Examples:"
	@echo "  make setup-dry-run --verbose"
	@echo "  make verify"
	@echo "  make clean"

$(LINK_CONFIG):
	@echo "No $(LINK_CONFIG) found — copying from example..."
	cp $(LINK_CONFIG_EXAMPLE) $(LINK_CONFIG)
	@echo "Edit $(LINK_CONFIG) with your workspace paths, then re-run make setup."
	@exit 1

setup: $(LINK_CONFIG) $(LINK_SCRIPT)
	@echo "Setting up symlinks from $(LINK_CONFIG)..."
	$(PYTHON) $(LINK_SCRIPT) --config $(LINK_CONFIG) --verbose

setup-dry-run: $(LINK_CONFIG) $(LINK_SCRIPT)
	@echo "Previewing symlink setup (dry-run)..."
	$(PYTHON) $(LINK_SCRIPT) --config $(LINK_CONFIG) --verbose --dry-run

update: setup
	@echo "Symlinks updated"

# list / verify both delegate to link_setup.py --check. The previous find/readlink
# loops assumed POSIX and silently reported nothing on Windows; --check is
# cross-platform, understands junctions, and additionally detects content drift on a
# real path where a link was expected -- which the link walk could not see at all.
list:
	@echo "Linked items per target (verbose):"
	$(PYTHON) $(LINK_SCRIPT) --config $(LINK_CONFIG) --check --verbose

verify:
	@echo "Verifying links (drift-aware; non-zero exit on drift or failure)..."
	$(PYTHON) $(LINK_SCRIPT) --config $(LINK_CONFIG) --check
	@echo ""
	@echo "Running repository structure smoke test..."
	@pwsh -NoProfile -NonInteractive -File scripts/smoke-test-plugin.ps1

# POSIX-only, and deliberately loud about it. These remove files, so a silent no-op on a
# platform where `find` is absent is the dangerous outcome: the operator believes links were
# removed when nothing happened. link_setup.py has no uninstall mode -- removal stays manual
# on Windows until it does.
clean:
	@command -v find >/dev/null 2>&1 || { echo "ERROR: 'clean' needs POSIX find; remove links manually on this platform."; exit 1; }
	@test -n "$(strip $(LINK_DIRS))" || { echo "Nothing to clean: no targets declared in $(LINK_CONFIG)."; exit 0; }
	@echo "Removing symlinks in target workspaces (keeping old/ and backups)..."
	@for d in $(LINK_DIRS); do \
	  find "$$d" -maxdepth 1 -type l -exec rm -v {} \; ; \
	done
	@echo "Symlinks removed"

clean-backups:
	@echo "Removing backup files..."
	@for d in $(LINK_DIRS); do \
	  find "$$d" -maxdepth 1 -name "*$(BACKUP_EXT)" -exec rm -v {} \; 2>/dev/null || true; \
	done
	@echo "Backups removed"

# Allowlisted paths: validator scripts (self-referential pattern definitions) and
# test fixtures (deliberately contain patterns or have CON-007 exempt changelog blocks).
ARCHAEOLOGY_ALLOW := \
  scripts/validate-no-archaeology.ps1 \
  scripts/validate-no-archaeology.sh \
  scripts/test-fixtures/archaeology-positive.md \
  scripts/test-fixtures/archaeology-negative.md \
  scripts/test-fixtures/valid-plan.md \
  scripts/test-fixtures/invalid-plan.md \
  scripts/test-fixtures/openq-a-cross-line-swallow.md \
  scripts/test-fixtures/openq-b-genuinely-unresolved.md \
  scripts/test-fixtures/openq-c-composite-id-collapse.md \
  scripts/test-fixtures/openq-d-table-resolved.md \
  scripts/test-fixtures/openq-e-list-resolved.md \
  scripts/test-fixtures/openq-f-undeclared-mention.md \
  scripts/test-fixtures/openq-g-section-prose-mention.md \
  scripts/test-fixtures/openq-h-valid-control.md \
  scripts/test-fixtures/req013-violation.md \
  scripts/test-fixtures/req013-control.md

# Argument-format helpers
comma := ,
empty :=
space := $(empty) $(empty)

# PowerShell -AllowList expects comma-joined list (no spaces); PS splits on comma for [string[]] params.
ARCHAEOLOGY_ALLOW_CSV := $(subst $(space),$(comma),$(strip $(ARCHAEOLOGY_ALLOW)))

# Bash --allow flag repeated per entry
ARCHAEOLOGY_ALLOW_SH := $(patsubst %,--allow %,$(strip $(ARCHAEOLOGY_ALLOW)))

check-archaeology:
	@echo "Checking for archaeological comments in consumer-facing files (pwsh)..."
	@pwsh -NoProfile -NonInteractive -File scripts/validate-no-archaeology.ps1 \
	  -RepoRoot . \
	  -AllowList $(ARCHAEOLOGY_ALLOW_CSV)

check-archaeology-sh:
	@echo "Checking for archaeological comments in consumer-facing files (bash)..."
	@bash scripts/validate-no-archaeology.sh \
	  -RepoRoot . \
	  $(ARCHAEOLOGY_ALLOW_SH)

.PHONY: $(LINK_SCRIPT)
.PHONY: check-archaeology check-archaeology-sh
