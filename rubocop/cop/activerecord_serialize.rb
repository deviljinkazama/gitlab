<<<<<<< HEAD
=======
require_relative '../model_helpers'

>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
module RuboCop
  module Cop
    # Cop that prevents the use of `serialize` in ActiveRecord models.
    class ActiverecordSerialize < RuboCop::Cop::Cop
<<<<<<< HEAD
      MSG = 'Do not store serialized data in the database, use separate columns and/or tables instead'.freeze

      def on_send(node)
        return unless in_models?(node)

        add_offense(node, :selector) if node.children[1] == :serialize
      end

      def models_path
        File.join(Dir.pwd, 'app', 'models')
      end

      def in_models?(node)
        path = node.location.expression.source_buffer.name

        path.start_with?(models_path)
      end
=======
      include ModelHelpers

      MSG = 'Do not store serialized data in the database, use separate columns and/or tables instead'.freeze

      def on_send(node)
        return unless in_model?(node)

        add_offense(node, :selector) if node.children[1] == :serialize
      end
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    end
  end
end
