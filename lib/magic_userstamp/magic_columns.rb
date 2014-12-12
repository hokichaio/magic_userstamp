# -*- coding: utf-8 -*-
require 'magic_userstamp'

module MagicUserstamp

  module MagicColumns
    def self.included(mod)
      mod.extend(ClassMethods)
      mod.instance_eval do
        alias :columns_without_userstamp :columns
        alias :columns :columns_with_userstamp
        alias :stampable_on_without_magic_columns :stampable_on
        alias :stampable_on :stampable_on_with_magic_columns
      end
    end

    module ClassMethods
      def ignore_userstamp(value = nil)
        @ignore_userstamp = value unless value.nil?
        !!@ignore_userstamp
      end

      def stampable_on_with_magic_columns(*args, &block)
        ignore_userstamp(true)
        stampable_on_without_magic_columns(*args, &block)
      end

      def columns_with_userstamp
        result = columns_without_userstamp
        unless @ignore_userstamp || @magic_columns_loaded
          setup_userstamp(result)
          @magic_columns_loaded = true
        end
        result
      end

      def setup_userstamp(columns)
        config = MagicUserstamp.config
        columns.each do |column|
          console.log column
          next if column.primary
          if pattern = config.pattern_for(self, column.name)
            stampable_on(*pattern.args_for_stampable_on(column.name))
          end
        end
      end

    end
  end
end
