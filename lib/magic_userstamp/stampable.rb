# -*- coding: utf-8 -*-
require 'magic_userstamp'

module MagicUserstamp
  # Determines what default columns to use for recording the current stamper.
  # By default this is set to false, so the plug-in will use columns named
  # <tt>creator_id</tt>, <tt>updater_id</tt>, and <tt>deleter_id</tt>.
  #
  # To turn compatibility mode on, place the following line in your environment.rb
  # file:
  #
  #   MagicUserstamp.compatibility_mode = true
  #
  # This will cause the plug-in to use columns named <tt>created_by</tt>,
  # <tt>updated_by</tt>, and <tt>deleted_by</tt>.
  mattr_accessor :compatibility_mode
  @@compatibility_mode = false

  VALID_OPTIONS_KEYS_FOR_STAMPABLE_ON = [
    :attribute, # :column_name
    :stamper_name,
    :stamper_class_name,
    :stamper_attr_name,
    :attribute,
    :actual_hook
  ]
  
  # Extends the stamping functionality of ActiveRecord by automatically recording the model
  # responsible for creating, updating, and deleting the current object. See the Stamper
  # and Userstamp modules for further documentation on how the entire process works.
  module Stampable
    def self.included(base) #:nodoc:
      base.extend(ClassMethods)
      base.class_eval do
        # Should ActiveRecord record userstamps? Defaults to true.
        class_attribute  :record_userstamp
        self.record_userstamp = true
      end
    end

    def self.raise_unless_valid_options_for_stampable_on(options)
      return if options.nil?
      invalid_keys = (options.keys - VALID_OPTIONS_KEYS_FOR_STAMPABLE_ON)
      raise "Invalid options keys: #{invalid_keys.inspect}" unless invalid_keys.empty?
    end

    module ClassMethods
      # This method is automatically called on for all classes that inherit from
      # ActiveRecord, but if you need to customize how the plug-in functions, this is the
      # method to use. Here's an example:
      #
      #   class Post < ActiveRecord::Base
      #     stampable :stamper_class_name => :person,
      #               :creator_attribute  => :create_user,
      #               :updater_attribute  => :update_user,
      #               :deleter_attribute  => :delete_user
      #   end
      #
      # The method will automatically setup all the associations, and create <tt>before_save</tt>
      # and <tt>before_create</tt> filters for doing the stamping.
      def stampable(options = {})
        reader_name = MagicUserstamp.compatibility_mode ? :default_attribute_compatible : :default_attribute
        options  = {
          :stamper_class_name => "User",
          :creator_attribute  => Event[:create ].send(reader_name),
          :updater_attribute  => Event[:update ].send(reader_name),
          :deleter_attribute  => Event[:destroy].send(reader_name)
        }.update(options || {})

        stamper_class_name = options[:stamper_class_name].to_s
        stamper_class_name = stamper_class_name.camelize unless stamper_class_name =~ /^[A-Z]/

        with_options(:stamper_class_name => stamper_class_name) do |s|
          s.stampable_on(:create , :attribute => options[:creator_attribute])
          s.stampable_on(:update , :attribute => options[:updater_attribute])
          s.stampable_on(:destroy, :attribute => options[:deleter_attribute]) if defined?(Caboose::Acts::Paranoid)
        end
      end

      def stampable_on(event_name, options = {})
        MagicUserstamp::Stampable.raise_unless_valid_options_for_stampable_on(options)
        event = Event[event_name]
        reader_name = MagicUserstamp.compatibility_mode ? :default_attribute_compatible : :default_attribute
        options = {
          :stamper_name => event.actor,
          :stamper_class_name => "User",
          # :stamper_attribute => nil
          :attribute => event.send(reader_name),
          :actual_hook => nil
        }.update(options || {})

        belongs_to_class_name = options[:stamper_class_name].to_s
        belongs_to_class_name = belongs_to_class_name.singularize.camelize unless belongs_to_class_name =~ /^[A-Z]/
        callback_method_name = "set_#{options[:attribute]}_on_#{event.name}"

        line_no = __LINE__ + 2
        method_definitions = <<-"EOS"
          belongs_to(:#{options[:stamper_name]},
            :class_name => '#{belongs_to_class_name}',
            :foreign_key => '#{options[:attribute].to_s}')

          #{options[:actual_hook] || event.actual_hook} :#{callback_method_name}

          def #{callback_method_name}
            if MagicUserstamp.config.verbose?(self.class, "#{options[:attribute]}") && !self.record_userstamp
              logger.debug("aborting #{self.name}.#{callback_method_name} cause of record_userstamp is #{self.record_userstamp.inspect}")
            end
            return unless self.record_userstamp
            if Rails.env == 'development'
              @@#{options[:attribute]}_stamper_class = "#{options[:stamper_class_name]}".constantize
            else
              @@#{options[:attribute]}_stamper_class ||= "#{options[:stamper_class_name]}".constantize
            end
            stamper_class = @@#{options[:attribute]}_stamper_class
            stamper_class.model_stamper if stamper_class
            stamper = stamper_class.stamper if stamper_class
            send("#{options[:attribute]}=", stamper) if stamper
            #{event.after_callback}
          end
        EOS
        if MagicUserstamp.config.verbose?(self, options[:attribute])
          ActiveRecord::Base.logger.debug "=" * 100
          ActiveRecord::Base.logger.debug self.name
          ActiveRecord::Base.logger.debug method_definitions
        end
        module_eval(method_definitions, __FILE__, line_no)
      end

      # Temporarily allows you to turn stamping off. For example:
      #
      #   Post.without_stamps do
      #     post = Post.find(params[:id])
      #     post.update_attributes(params[:post])
      #     post.save
      #   end
      def without_stamps
        original_value = self.record_userstamp
        self.record_userstamp = false
        begin
          yield
        ensure
          self.record_userstamp = original_value
        end
      end
    end
  end
end
