# coding: utf-8

require 'ast'

module Transpec
  class Syntax
    class RSpecConfigure
      class Framework
        include ::AST::Sexp

        def initialize(rspec_configure_node, framework_block_method_name, source_rewriter)
          @rspec_configure_node = rspec_configure_node
          @framework_block_method_name = framework_block_method_name
          @source_rewriter = source_rewriter
        end

        def syntaxes
          return [] unless syntaxes_node

          case syntaxes_node.type
          when :sym
            [syntaxes_node.children.first]
          when :array
            syntaxes_node.children.map do |child_node|
              child_node.children.first
            end
          else
            fail UnknownSyntaxError, "Unknown syntax specification: #{syntaxes_node}"
          end
        end

        def syntaxes=(syntaxes)
          unless [Array, Symbol].include?(syntaxes.class)
            fail ArgumentError, 'Syntaxes must be either an array or a symbol.'
          end

          @source_rewriter.replace(syntaxes_node.loc.expression, syntaxes.inspect)
        end

        private

        def syntaxes_node
          return @syntaxes_node if instance_variable_defined?(:@syntaxes_node)

          syntax_setter_node = find_configuration_node(:syntax=)

          @syntaxes_node = if syntax_setter_node
                             syntax_setter_node.children[2]
                           else
                             nil
                           end
        end

        def find_configuration_node(configuration_method_name)
          return nil unless framework_block_node

          configuration_method_name = configuration_method_name.to_sym

          framework_block_node.each_descendent_node.find do |node|
            next unless node.send_type?
            receiver_node, method_name, = *node
            next unless receiver_node == s(:lvar, framework_block_arg_name)
            method_name == configuration_method_name
          end
        end

        def framework_block_arg_name
          return nil unless framework_block_node
          first_block_arg_name(framework_block_node)
        end

        def framework_block_node
          return @framework_block_node if instance_variable_defined?(:@framework_block_node)

          @framework_block_node = @rspec_configure_node.each_descendent_node.find do |node|
            next unless node.block_type?
            send_node = node.children.first
            receiver_node, method_name, *_ = *send_node
            next unless receiver_node == s(:lvar, rspec_configure_block_arg_name)
            method_name == @framework_block_method_name
            # TODO: Check expectation framework.
          end
        end

        def rspec_configure_block_arg_name
          first_block_arg_name(@rspec_configure_node)
        end

        def first_block_arg_name(block_node)
          args_node = block_node.children[1]
          first_arg_node = args_node.children.first
          first_arg_node.children.first
        end

        class UnknownSyntaxError < StandardError; end
      end
    end
  end
end
