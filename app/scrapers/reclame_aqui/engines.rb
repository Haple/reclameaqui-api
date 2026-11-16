module ReclameAqui
  module Engines
    class InvalidParams < StandardError; end

    module_function

    def all
      [ CompanySearch, Company, Complaints, Complaint ]
    end

    def fetch(name)
      all.find { |engine| engine.engine_name == name } ||
        raise(InvalidParams, name.blank? ? "Missing `engine` parameter." : "Unsupported `#{name}` search engine.")
    end

    def build(params)
      fetch(params["engine"].to_s).new(params)
    end
  end
end
