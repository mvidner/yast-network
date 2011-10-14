# Makefile.am for network/src/modules
# $Id$

module_DATA = $(wildcard *.ycp)
EXTRA_DIST = $(module_DATA)

YCPCFLAGS = -I../include

all: YaPI
dist-hook: YaPI
YaPI:
	test -L $@ || ln -snf ../lan/YaPI $@

include $(top_srcdir)/Makefile.am.common
