all: network
dist-hook: network

network:
	test -L $@ || ln -snf ../routines $@
