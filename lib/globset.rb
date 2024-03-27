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
      attr_reader :value

      def initialize
        @exact_transitions = {}
        @complex_transitions = {}
        @doublestar_transition = nil
        @value = nil
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

      def set_value(value)
        @value = value
      end

      def get!(segment)
        if segment.include?("*")
          # FIXME: actually implement
          escaped = Regexp.escape(segment)
          regex = escaped.gsub("\\*", ".*")
          regex = "\\A#{regex}\\z"
          @complex_transitions[Regexp.new(regex)] ||= State.new
        else
          @exact_transitions[segment] ||= State.new
        end
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

        if pattern.start_with?("**/")
          doublestar_transition!.add(pattern.delete_prefix("**/"), value)
        elsif pattern.include?("/")
          prefix, tail = pattern.split("/", 2)
          get!(prefix).add(tail, value)
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
        if !anchored && !pattern.include?("/")
          initial_node = @root.doublestar_transition!
        end
        initial_node.add(pattern)
      end
    end

    def match(pattern)
      initial_states = [@root, @root.doublestar_transition].compact
      #p pattern
      states = initial_states.dup
      results = initial_states.map(&:value).compact
      pattern.split("/", -1).each do |segment|
        #p segment: segment
        #p(segment, states: states.size)
        next_states = []
        states.each do |from_state|
          from_state.states_matching(segment) do |to_state|
            next_states << to_state
            next_states << to_state.doublestar_transition
            results << to_state.value
          end
        end
        states = next_states.compact.uniq
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
