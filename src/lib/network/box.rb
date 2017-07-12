class Module
  # An accessor for a {Box}.
  # Like `attr_accessor :foo`, `box_accessor :foo` defines `foo` and `foo=`.
  # These translate to `@foo_box.value` and `@foo_box.value=`.
  # This is useful if we had a plain `@foo` before and now we replaced
  # it with a {StagingBox} where we want to call `@foo_box.commit`
  # @note `@foo_box` must be initialized elsewhere
  def box_accessor(symbol)
    define_method(symbol) do
      instance_variable_get("@#{symbol}_box").value
    end

    define_method("#{symbol}=") do |v|
      instance_variable_get("@#{symbol}_box").value = v
    end
  end
end

module Yast2
  # A Box is a wrapper for a value. So it has two methods,
  # {#value} (aliased as {#read}) and {#value=} (aliased as {#write}).
  # That is not useful in itself, but specialized boxes build upon this
  # interface to provide useful functions:
  #
  # - persistent storage via {Yast::SCR}: {ScrBox}
  # - caching: {ReadCachingBox}, {ReadWriteCachingBox}
  # - reinterpreting the value: {BooleanBox}
  #
  # FIXME: how does this relate to CFA?!
  class Box
    attr_accessor :value

    # These aliases will work also in subclasses.
    # (If we said `alias read value`, they wouldn't.)

    alias_method :read, :value
    alias_method :write, :value=
  end

  # A {Box} that translates *value* access
  # to {Yast::SCR.Read} and {Yast::SCR.write}
  # at a given *path*.
  class ScrBox < Box
    # @param path [Yast::Path,String]
    def initialize(path:)
      path = Yast::Path.new(path) if path.is_a? ::String
      @path = path
    end

    def value
      Yast::SCR.Read(@path)
    end

    def value=(v)
      Yast::SCR.Write(@path, v)
      v
    end
  end

  # A Box that sits upon a lower layer box and caches its reads ({#value}).
  #
  # Note that the implementation is not just a `||=` so it is safe even
  # for booleans and `nil`.
  class ReadCachingBox < Box
    # @param lower [Box]
    def initialize(lower)
      @b = lower
      @have_read = false
    end

    def value
      if !@have_read
        @value = @b.value
        @have_read = true
      end
      @value
    end

    def value=(v)
      @have_read = true
      @value = v
      @b.value = @value
    end
  end

  # Reads are cached, also writes are cached: redundant ones eliminated.
  class CachingBox < ReadCachingBox
    def value=(v)
      if @have_read && @value == v
        # write cache: if we know the value is the same, don't perform the write
        return v
      end
      super
    end
  end

  # A `true` and `false` wrapper for a lower box that uses `"yes"` and `"no"`.
  # When writing, `{#value=}nil` becomes `nil`.
  # When reading, `nil` becomes `nil` but that is configurable,
  # other values become `false` but that is configurable.
  class BooleanBox < Box
    # We could generalize this into a lookup-based TranslatorBox

    # @param lower [Box]
    # @param for_nil     [nil,true,false]
    #   what {#value} should return when lower.value is `nil`
    # @param for_other [nil,true,false]
    #   what {#value} should return when lower.value
    #   is none of `"yes"`, `"no"`, `nil`
    def initialize(lower, for_nil: nil, for_other: false)
      @b = lower
      @for_nil = for_nil
      @for_other = for_other
    end

    def value
      case @b.value
      when "yes" then true
      when "no" then false
      when nil then @for_nil
      else @for_other
      end
    end

    def value=(v)
      vv = case v
           when true then "yes"
           when false then "no"
           when nil then nil
           else raise ArgumentError, "BooleanBox cannot accept #{v.inspect}"
           end
      @b.value = vv
    end
  end

  # This {Box} adds a *draft* box on top of a *production* box:
  # a {#value=} alone writes only to the draft box, and a{#commit} is
  # needed to write to the production box.
  # A {#reset} may be used to remove the draft box.
  class StagingBox < Box
    def initialize(production)
      @production = production
      reset
    end

    def reset
      @draft = nil
    end

    def value
      (@draft || @production).value
    end

    def value=(v)
      @draft ||= Box.new
      @draft.value = v
    end

    # If a draft box is present, write it to the production box.
    # @return [Boolean] did we actually need to commit anything
    def commit
      return false if @draft.nil? || @production.value == @draft.value
      @production.value = @draft.value
      true
    end
  end

  class SysconfigBooleanBox < StagingBox
    def initialize(path:)
      super(BooleanBox.new(CachingBox.new(ScrBox.new(path: path))))
    end
  end

  # SCR.Write(".sysconfig.locale.COUNTRY", "Lorien")
  # SCR.Write(".sysconfig.locale.LANGUAGE", "Quenya")
  # SCR.Write(".sysconfig.locale", nil)
  class SysconfigBoxGroup
    def initialize(path:)
      @members = []
      @commit_path = path
    end

    # Add a {StagingBox} member to the group
    # @param b [StagingBox]
    def <<(b)
      @members << b
    end

    # {StagingBox#commit} all members,
    # and if any of them really needed it, commit the group.
    def commit
      changed = @members.map(&:commit).any?
      Yast::SCR::Write(@commit_path, nil) if changed
      changed
    end

    # {StagingBox#reset} all members.
    def reset
      @members.each(&:reset)
    end
  end
end
