# frozen_string_literal: true

require_relative "globset/version"

module Globset
  class Error < StandardError; end

  class Matcher
    class Includes
      def initialize(pattern)
        @pattern = pattern
      end

      def match?(string)
        string.include?(@pattern)
      end
    end
  end

  class NFA
    class State
      attr_reader :value, :final_value

      def initialize
        @exact_transitions = {}
        @complex_transitions = {}
        @doublestar_transition = nil
        @value = nil
        @final_value = nil
      end

      # The "doublestar" transition is a special case of the epsilon
      # transition with a wildcard edge looping onto itself.
      # This implies that once visited we never leave the doublestar state.
      # This is the only type of epsilon transition we need, simplifying
      # implementation.
      attr_accessor :doublestar_transition
      def doublestar_transition!
        @doublestar_transition ||= State.new.tap do |t|
          t.doublestar_transition = t
        end
      end

      def set_value(value, final=false)
        if final
          @final_value = value
        else
          @value = value
        end
      end

      def get!(segment)
        if segment.include?("*") || segment.include?("?")
          regex = translate_to_regex(segment)
          @complex_transitions[Regexp.new(regex)] ||= State.new
        else
          @exact_transitions[segment] ||= State.new
        end
      end

      def translate_to_regex(original)
        # FIXME: actually implement
        chars = original.chars
        output = +""
        while c = chars.shift
          if c == "\\"
            output << Regexp.escape(chars.shift)
          elsif c == "*"
            output << ".*"
          elsif c == "?"
            output << "."
          else
            output << Regexp.escape(c)
          end
        end
        Regexp.new("\\A#{output}\\z")
      end

      def states_matching(segment)
        return enum_for(__method__, segment) unless block_given?
        if state = @exact_transitions[segment]
          yield state
        end
        @complex_transitions.each do |pattern, state|
          if pattern.match?(segment)
            yield state
          end
          # fixme: match
        end
        if @doublestar_transition
          yield @doublestar_transition
        end
      end

      def add(pattern, value = pattern)
        if pattern.start_with?("/")
          pattern = pattern[1..]
        end

        if pattern.empty?
          # trailing slash
          get!("*").set_value(value)
        elsif pattern.start_with?("**/")
          doublestar_transition!.add(pattern.delete_prefix("**/"), value)
        elsif pattern.include?("/")
          prefix, tail = pattern.split("/", 2)
          get!(prefix).add(tail, value)
        elsif pattern == "*"
          # trailing '*'
          get!(pattern).set_value(value, true)
        else
          # terminal
          get!(pattern).set_value(value)
        end
      end
    end

    attr_reader :root

    def initialize(patterns, anchored: false)
      @root = State.new

      patterns.each do |pattern|
        initial_node = @root
        if !anchored && !pattern.include?("/") || (pattern.end_with?("/") && pattern.count("/") == 1)
          initial_node = @root.doublestar_transition!
        end
        initial_node.add(pattern)
      end
    end

    def match(pattern)
      initial_states = [@root, @root.doublestar_transition].compact
      #p pattern
      segments = pattern.split("/", -1)
      states = initial_states.dup
      results = []
      segments.each do |segment|
        # collect values from current states
        states.each do |state|
          results << state.value
        end

        next_states = []
        states.each do |from_state|
          from_state.states_matching(segment) do |to_state|
            next_states << to_state
            next_states << to_state.doublestar_transition
          end
        end
        states = next_states.compact.uniq
      end

      # Add final states values. These only exist from trailing "/*" segments
      # which forbid matching in the middle of the pattern.
      states.each do |state|
        results << state.value
        results << state.final_value
      end

      results.compact!

      results.empty? ? nil : results
    end
  end

  class Set
    attr_reader :patterns

    def initialize()
      @patterns = []
    end

    def size
      @patterns.size
    end

    def dynamic_patterns
      @patterns.select do |x|
        x.include?("*") || x.include?("?")
      end
    end

    def add(pattern)
      @patterns << pattern
    end
  end
end
