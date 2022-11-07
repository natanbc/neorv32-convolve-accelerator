# __override_default(variable_name,value)
#
# Returns the value that should be set for the variable,
# such that the given value overrides the make defaults,
# but an explicitly passed variable (command line or environment
# variable) overrides the provided value.
#
# override XYZ := $(call __override_default,XYZ,my-value)
define __override_default
  $(strip $(if $(findstring $(origin $(1)), default),
    $(2),
    $(if $($(1)),
	  $($(1)),
	  $(2)
	)
  ))
endef

# Work around nixos forcing architecture
__NIXOS=$(shell [ -e /etc/os-release ] && grep ID=nixos /etc/os-release)

# __unwrap_llvm_bin(binary_name,path)
# 
# If on nixos, extract the real binary from the wrapper script at `path`,
# otherwise return `path` unmodified
define __unwrap_llvm_bin
	$(strip
		$(if $(2),
			$(if $(__NIXOS),
				$(shell grep -oP '^\s*(exec\s+)?\K(/nix/store/.*/$(1))' -m 1 $(2)),
				$(2)
			),
		)
	)
endef

# __set_llvm_bin_unwrap(variable_name,exe_name)
#
# Overrides the default value of `variable_name` with the path to
# the LLVM `exe_name` program, extracting the real executable from
# NixOS wrapper scripts.
define __set_llvm_bin_unwrap
    override $(1) := $(call __override_default,$(1),$(call __unwrap_llvm_bin,$(2),$(shell command -v $(2))))
endef

# __set_llvm_bin(variable_name,exe_name)
#
# Overrides the default value of `variable_name` with the path to
# the LLVM `exe_name` program.
define __set_llvm_bin
	override $(1) := $(call __override_default,$(1),$(shell command -v $(2)))
endef

HOSTCC ?= cc
$(eval $(call __set_llvm_bin_unwrap,CC,clang))
$(eval $(call __set_llvm_bin_unwrap,CXX,clang++))
$(eval $(call __set_llvm_bin_unwrap,LD,ld.lld))
$(eval $(call __set_llvm_bin,OBJCOPY,llvm-objcopy))
$(eval $(call __set_llvm_bin,OBJDUMP,llvm-objdump))

__VARS=CC CXX LD OBJCOPY OBJDUMP
_:=$(foreach var,$(__VARS),$(if $($(var)),,$(error Unable to find $(var))))

