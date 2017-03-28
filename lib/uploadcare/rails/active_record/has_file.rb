require "uploadcare/rails/objects/file"

module Uploadcare
  module Rails
    module ActiveRecord
      def has_uploadcare_file(attribute, options={})

        define_method "has_#{attribute}_as_uploadcare_file?" do
          true
        end

        define_method "has_#{attribute}_as_uploadcare_group?" do
          false
        end

        define_method "build_file_#{attribute}" do
          cdn_url = attributes[attribute.to_s].to_s
          return nil if cdn_url.blank?

          api = ::Rails.application.config.uploadcare.api
          cache = ::Rails.cache

          if file_obj = cache.read(cdn_url)
            Uploadcare::Rails::File.new(api, cdn_url, file_obj)
          else
            Uploadcare::Rails::File.new(api, cdn_url)
          end
        end

        define_method "#{attribute}" do
          send(:"build_file_#{attribute}")
        end

        define_method "check_#{attribute}_for_uuid" do
          url = attributes[attribute.to_s]
          if url.present?
            result = Uploadcare::Parser.parse(url)
            raise "Invalid Uploadcare file uuid" unless result.is_a?(Uploadcare::Parser::File)
          end
        end

        define_method "store_#{attribute}" do
          file = send(:"build_file_#{attribute}")
          return unless file
          file.store
          ::Rails.cache.write(file.cdn_url, file.marshal_dump) if UPLOADCARE_SETTINGS.cache_files
          file
        end

        define_method "delete_#{attribute}" do
          file = send(:"build_file_#{attribute}")
          return unless file
          file.delete
          ::Rails.cache.write(file.cdn_url, file.marshal_dump) if UPLOADCARE_SETTINGS.cache_files
          file
        end

        before_save :"check_#{attribute}_for_uuid"
        after_save :"store_#{attribute}" if UPLOADCARE_SETTINGS.store_after_save
        after_destroy :"delete_#{attribute}" if UPLOADCARE_SETTINGS.delete_after_destroy
      end
    end
  end
end

ActiveRecord::Base.extend Uploadcare::Rails::ActiveRecord
