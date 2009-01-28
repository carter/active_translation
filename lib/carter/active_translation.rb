module Carter
  module ActiveTranslation
    def self.included(base)
      base.extend ClassMethods
    end
    
    module ClassMethods
      def has_translations_for(*columns)
        # setup only once
        unless included_modules.include? InstanceMethods
          include InstanceMethods
          # setup translation proxy class
          proxy_class = Object.const_set "#{self.name}Translation", Class.new(::ActiveRecord::Base)
        
          # setup translation has_many
          has_many :translations, :class_name => proxy_class.name
        
          # setup getter and setter methods for all the translated columns
          columns.each do |column|
            define_method column do
              get_translation(column)
            end
            
            define_method "#{column}=" do |value|
              set_translation(column, value)
            end
          end
        end
      end
      
    end
    
    module InstanceMethods
      def set_translation(field, value, language=nil)
        language ||= I18n.locale
        if I18n.locale == I18n.default_locale # if we should use the base then we'll just write an attrib
          write_attribute(field, value)
        else
          translation = self.translations.find_or_initialize_by_locale(I18n.locale.to_s)
          translation.write_attribute(field, value)
          translation.save
        end
      end

      def get_translation(field, language=nil)
        language ||= I18n.locale
        field = field.to_s if field.is_a?(Symbol)
        if language.to_s == I18n.default_locale.to_s
          return self.attributes[field]
        elsif translation = self.translations.find(:first, :conditions => ['locale = ?', language.to_s])
          return translation.attributes[field] || attributes[field]
        else
          return self.attributes[field]
        end
      end
    end
  end
end