# frozen_string_literal: true

require 'mobility/backends/active_record/key_value'

module Mobility
  # -
  module Backends
    #
    # Implements the {Mobility::Backends::KeyValue} backend for ActionText.
    #
    # @example
    #   class Post < ApplicationRecord
    #     extend Mobility
    #     translates :content, backend: :action_text
    #   end
    #
    #   post = Post.create(content: "<h1>My text is rich</h1>")
    #   post.rich_text_translations
    #   #=> #<ActionText::RichText::ActiveRecord_Associations_CollectionProxy ... >
    #   post.rich_text_translations.first.to_s
    #   #=> "<div class=\"trix-content\">\n  <h1>My text is rich</h1>\n</div>\n"
    #   post.content
    #   #=> "<div class=\"trix-content\">\n  <h1>My text is rich</h1>\n</div>\n"
    #   post.rich_text_translations.first.class
    #   #=> Mobility::Backends::ActionText::Translation
    #
    class ActionText < ActiveRecord::KeyValue
      # override to return record instead of value
      def read(locale, **options)
        translation_for(locale, **options)
      end

      class << self
        # @!group Backend Configuration
        # @option (see Mobility::Backends::KeyValue::ClassMethods#configure)
        def configure(options)
          raise ArgumentError, 'The type option is unsupported with this backend.' if options[:type]

          options[:association_name] ||= 'rich_text_translations'
          options[:class_name]       ||= Translation
          options[:key_column]       ||= :name
          options[:value_column]     ||= :body
          options[:belongs_to]       ||= :record
          super
        end
        # @!endgroup
      end

      setup do |attributes, _options|
        attributes.each do |name|
          has_one :"rich_text_#{name}", -> { where(name: name, locale: Mobility.locale) },
                  class_name: 'ActionText::RichText',
                  as: :record, inverse_of: :record, autosave: true, dependent: :destroy
          scope :"with_rich_text_#{name}", -> { includes("rich_text_#{name}") }
          scope :"with_rich_text_#{name}_and_embeds",
                -> { includes("rich_text_#{name}": { embeds_attachments: :blob }) }
        end
      end

      # Model for translated rich text
      class Translation < ::ActionText::RichText
        validates :name,
                  presence: true,
                  uniqueness: { scope: %i[record_id record_type locale], case_sensitive: true }
        validates :record, presence: true
        validates :locale, presence: true
      end
    end

    register_backend(:action_text, ActionText)
  end
end
