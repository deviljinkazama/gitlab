<<<<<<< HEAD
=======
require 'rubocop-rspec'

>>>>>>> upstream/master
module RuboCop
  module Cop
    module RSpec
      # This cop checks for single-line hook blocks
      #
      # @example
      #
      #   # bad
      #   before { do_something }
      #   after(:each) { undo_something }
      #
      #   # good
      #   before do
      #     do_something
      #   end
      #
      #   after(:each) do
      #     undo_something
      #   end
<<<<<<< HEAD
      class SingleLineHook < RuboCop::Cop::RSpec::Cop
=======
      class SingleLineHook < Cop
>>>>>>> upstream/master
        MESSAGE = "Don't use single-line hook blocks.".freeze

        def_node_search :rspec_hook?, <<~PATTERN
          (send nil {:after :around :before} ...)
        PATTERN

        def on_block(node)
          return unless rspec_hook?(node)
          return unless node.single_line?

          add_offense(node, :expression, MESSAGE)
        end
      end
    end
  end
end
