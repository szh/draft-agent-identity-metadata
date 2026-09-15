LIBDIR := lib

# Paginate the text output so the local artifact matches what the datatracker
# renders on submission. Without this, idnits reports missing formfeeds, a
# missing Expires line, and spurious section-title indentation nits.
TEXT_PAGINATION := true

-include $(LIBDIR)/main.mk

$(LIBDIR)/main.mk:
ifneq (,$(shell grep "path *= *$(LIBDIR)" .gitmodules 2>/dev/null))
	git submodule sync
	git submodule update --init
else
ifneq (,$(wildcard $(ID_TEMPLATE_HOME)))
	ln -s "$(ID_TEMPLATE_HOME)" $(LIBDIR)
else
	git clone -q --depth 10 -b main \
	    https://github.com/martinthomson/i-d-template $(LIBDIR)
endif
endif
