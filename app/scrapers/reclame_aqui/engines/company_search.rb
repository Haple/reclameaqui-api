module ReclameAqui
  module Engines
    class CompanySearch < Base
      engine "reclame_aqui",
        title: "Reclame Aqui Search API",
        summary: "Finds companies by name, with their reputation, the way the site's search box suggests them."

      param :q, required: true, description: "Company name to search for, for example `nubank` or `123 milhas`."

      def source_url
        Urls.company_search(params["q"])
      end

      def parse(body)
        Parsers::CompanySearch.parse(JsonDocument.parse(body)).deep_stringify_keys
      end

      def decorate(results, links)
        each_item(results, "companies") { |company| company["api_link"] = links.company(company["company_id"]) }
        results
      end

      def companies_seen(results)
        Array(results["companies"]).map { |company| company.values_at("company_id", "id") }
      end
    end
  end
end
