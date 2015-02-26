module Curlybars
  module Node
    With = Struct.new(:path, :template, :position) do
      def compile
        <<-RUBY
          compiled_path = #{path.compile}.call

          #{check_context_is_presenter}

          contexts << compiled_path
          begin
            buffer.safe_concat(#{template.compile})
          ensure
            contexts.pop
          end
        RUBY
      end

      private

      def check_context_is_presenter
        <<-RUBY
          unless compiled_path.class.respond_to? :allows_method?
            position = hbs.position(#{position.line_number}, #{position.line_offset})
            message = "`#{path.path}` is not a context type object"
            raise Curlybars::Error::Render.new('context_is_not_a_presenter', message, position)
          end
        RUBY
      end
    end
  end
end
