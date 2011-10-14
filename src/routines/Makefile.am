#
# Makefile.am for y2c_network/src/modules
#
# $Id$
#

yncludedir = @yncludedir@/network
ynclude_DATA = $(wildcard *.ycp)

EXTRA_DIST = $(ynclude_DATA)

all: $(idirs)
dist-hook: $(idirs)
idirs := lan isdn modem dsl installation provider remote services
${idirs}: %:
	test -L $@ || ln -snf ../$* $@
