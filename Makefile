PREFIX  ?= $(HOME)/.local
BINDIR   = $(PREFIX)/bin
UNITDIR  = $(HOME)/.config/systemd/user
CONFDIR  = $(HOME)/.config/timelapse

SCRIPTS  = timelapse-capture timelapse-compile timelapse-compile-daily
UNITS    = timelapse-capture.service \
           timelapse-compile-daily.service \
           timelapse-compile-daily.timer

.PHONY: install uninstall enable disable

install:
	mkdir -p $(BINDIR) $(UNITDIR) $(CONFDIR)
	for s in $(SCRIPTS); do \
		sed 's|@BINDIR@|$(BINDIR)|g' $$s > $(BINDIR)/$$s; \
		chmod 755 $(BINDIR)/$$s; \
	done
	for u in $(UNITS); do \
		sed 's|@BINDIR@|$(BINDIR)|g' systemd/$$u > $(UNITDIR)/$$u; \
	done
	@if [ ! -f $(CONFDIR)/config ]; then \
		cp timelapse.conf.sample $(CONFDIR)/config; \
		echo "Default config installed to $(CONFDIR)/config — please review it."; \
	else \
		echo "Config already exists at $(CONFDIR)/config — skipping."; \
	fi
	systemctl --user daemon-reload
	@echo ""
	@echo "Done. Run 'make enable' to start the services."

uninstall: disable
	for s in $(SCRIPTS); do rm -f $(BINDIR)/$$s; done
	for u in $(UNITS); do rm -f $(UNITDIR)/$$u; done
	systemctl --user daemon-reload

enable:
	systemctl --user enable --now timelapse-capture.service
	systemctl --user enable --now timelapse-compile-daily.timer

disable:
	-systemctl --user disable --now timelapse-capture.service
	-systemctl --user disable --now timelapse-compile-daily.timer
