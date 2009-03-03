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
            
            # necessary for providing compatibility to Rails form helpers
            define_method "#{column}_before_type_cast" do
              get_translation(column)
            end
            
            define_method "#{column}=" do |value|
              set_translation(column, value)
            end
          end
          
          # before filter for saving translation queue
          after_save :save_translations
        end
      end
      
    end
    
    module InstanceMethods
      def save_translations
        if @translations_to_save && @translations_to_save.any?
          @translations_to_save.each do |k,t|
            self.translations << t
            t.save
          end
          @translations_to_save = {}
        end
        
        return true
      end
      
      def set_translation(field, value, language=nil)
        @translations_to_save ||= {}
        language ||= I18n.locale
        if I18n.locale.to_s == I18n.default_locale.to_s # if we should use the base then we'll just write an attrib
          write_attribute(field, value)
        else
          @translations_to_save[language.to_sym] ||= self.translations.find_or_initialize_by_locale(I18n.locale.to_s)
          @translations_to_save[language.to_sym].write_attribute(field, value)
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