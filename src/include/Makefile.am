# begin generic
# usage:
#  SYMLINK_REQUIRED_DIR_foo = bar
# makes rules to symlink foo to bar
# and makes 'all' and 'dist-hook' depend on them

# $(1) symlink target
#      (which is not even a makefile dependency, much less target)
# $(2) link name (which is a *makefile* target, $@)
## define: See info '(make)Multi-Line'
define symlink_required_dir =
all: $(2)
dist-hook: $(2)
$(2):
	test -L $$@ || ln -snf $(1) $$@
endef

# note: symlink_required_dir must be defined before the loop

# The loop expands to $(eval $(call symlink_required_dir, bar, foo))
## eval: See info '(make)Eval Function'
$(foreach dirvar,\
    $(filter SYMLINK_REQUIRED_DIR_%,$(.VARIABLES)),\
    $(eval $(call symlink_required_dir,\
                  $($(dirvar)),\
                  $(dirvar:SYMLINK_REQUIRED_DIR_%=%))\
     )\
 )
# end generic

SYMLINK_REQUIRED_DIR_network = ../routines
