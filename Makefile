SUBDIRS = pusagi_vala pusagi_ocaml pusagi_qt6 pusagi_rust pusagi_haskell

.PHONY: all clean $(SUBDIRS) $(addprefix clean-,$(SUBDIRS))

all: $(SUBDIRS)

pusagi_vala:
	$(MAKE) -C $@

pusagi_ocaml:
	$(MAKE) -C $@

pusagi_qt6:
	$(MAKE) -C $@

pusagi_rust:
	$(MAKE) -C $@

pusagi_haskell:
	$(MAKE) -C $@

clean: $(addprefix clean-,$(SUBDIRS))

clean-pusagi_vala:
	$(MAKE) -C pusagi_vala clean

clean-pusagi_ocaml:
	$(MAKE) -C pusagi_ocaml clean

clean-pusagi_qt6:
	$(MAKE) -C pusagi_qt6 clean

clean-pusagi_rust:
	$(MAKE) -C pusagi_rust clean

clean-pusagi_haskell:
	$(MAKE) -C pusagi_haskell clean
