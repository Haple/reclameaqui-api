module ReclameAqui
  module Parsers
    # engine=reclame_aqui, from the company autocomplete behind the site's search box:
    # iosearch.reclameaqui.com.br/.../companies/search/{q}
    class CompanySearch
      include Normalize

      def self.parse(json)
        new(json).parse
      end

      def initialize(json)
        @json = json
      end

      def parse
        companies = @json["companies"]
        raise ParseError, "companies not found" unless companies.is_a?(Array)

        prune(
          search_information: { total_results: companies.size },
          companies: companies.each_with_index.map { |company, index| company(company, index + 1) }
        )
      end

      private

      def company(company, position)
        prune(
          position:,
          id: company["id"],
          company_id: company["shortname"],
          name: company["companyName"].presence || company["name"],
          logo: company["logo"],
          score: number(company["finalScore"]),
          status: company["status"],
          status_label: status_label(company["status"]),
          solved_rate: number(company["solvedPercentual"]),
          complaints: company["count"],
          verified: company["hasVerificada"],
          cnpj: cnpj(Array(company["documents"]).first),
          website: company["url"].presence,
          location: prune(city: company["city"].presence, state: company["state"].presence),
          previous_names: company["previousNames"],
          link: Urls.company(company["shortname"])
        )
      end
    end
  end
end
