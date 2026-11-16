module ReclameAqui
  module Engines
    # One SerpApi-style engine: declares its parameters, builds the Reclame Aqui
    # URL to fetch and turns the response into JSON. Results are plain hashes with
    # string keys, the shape they are stored in and served back from MongoDB.
    class Base
      Param = Data.define(:name, :required, :description, :default, :allowed, :format)

      SLUG = /\A[\w-]+\z/

      class << self
        attr_reader :engine_name, :title, :summary

        def engine(name, title:, summary:)
          @engine_name = name
          @title = title
          @summary = summary
        end

        def param(name, description:, required: false, default: nil, allowed: nil, format: nil)
          params_spec << Param.new(name: name.to_s, required:, description:, default:, allowed:, format:)
        end

        def params_spec
          @params_spec ||= []
        end

        def xray
          const_defined?(:XRAY, false) ? self::XRAY : {}
        end
      end

      attr_reader :params

      def initialize(raw_params)
        @params = self.class.params_spec.each_with_object({}) do |spec, params|
          value = raw_params[spec.name].to_s.strip.presence || spec.default
          params[spec.name] = value unless value.nil?
        end
        validate!
      end

      def search_parameters
        { "engine" => self.class.engine_name }.merge(params)
      end

      # Hook for engines that need a lookup before they know which URL to fetch.
      def prepare(_client); end

      def source_url
        raise NotImplementedError
      end

      def parse(_body)
        raise NotImplementedError
      end

      # Adds api_link fields that point back into this API. Needs the request's
      # host, so it runs when a search is served rather than when it is parsed.
      def decorate(results, _links)
        results
      end

      # [company_id, Reclame Aqui id] pairs seen in the results, cached so the
      # complaints engine can skip a lookup later.
      def companies_seen(_results)
        []
      end

      private

      def validate!
        self.class.params_spec.each do |spec|
          value = params[spec.name]
          raise InvalidParams, "Missing `#{spec.name}` parameter." if spec.required && value.blank?
          next if value.nil?

          if spec.allowed && !spec.allowed.include?(value)
            raise InvalidParams, "Unsupported `#{spec.name}` value: #{value}. Use one of: #{spec.allowed.join(', ')}."
          end
          raise InvalidParams, "Invalid `#{spec.name}` value: #{value}." if spec.format && !value.match?(spec.format)
        end
      end

      def each_item(results, key, &)
        Array(results[key]).each(&)
      end
    end
  end
end
