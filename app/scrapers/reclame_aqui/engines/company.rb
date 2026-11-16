module ReclameAqui
  module Engines
    class Company < Base
      engine "reclame_aqui_company",
        title: "Reclame Aqui Company API",
        summary: "A company's page: reputation for every period, reputation history, main problems, latest complaints and related companies."

      param :company_id, required: true, format: SLUG,
        description: "The company's slug, as in reclameaqui.com.br/empresa/`company_id`/. Returned by the Search API."

      # Where each top-level key is shown on the page, for the playground's X-Ray.
      XRAY = {
        "company_info" => '[data-company-home-section="about"]',
        "company_info.phones" => '[data-company-home-section="contact"]',
        "company_info.website" => '[data-company-home-section="contact"]',
        "reputation" => '[data-company-home-section="reputation-performance"]',
        "reputation_by_period" => '[data-company-home-section="reputation-performance"]',
        "reputation_history" => '[data-company-home-section="reputation-history"]',
        "ranking" => '[data-company-home-section="company-ranking"]',
        "main_problems" => '[data-company-home-section="main-problems"]',
        "recent_complaints" => '[data-company-home-section="complaints"]',
        "related_companies" => '[data-company-home-section="people-also-visited"]',
        "alerts" => 'astro-island[component-url*="CompanyCrisisAlertIsland"]',
        "award" => '[data-company-home-section="award-stamp"]'
      }.freeze

      def source_url
        Urls.company(params["company_id"])
      end

      def parse(body)
        Parsers::CompanyPage.parse(body).deep_stringify_keys
      end

      def decorate(results, links)
        company_id = results.dig("company_info", "company_id") || params["company_id"]
        results["company_info"]["complaints_api_link"] = links.complaints(company_id) if results["company_info"]
        each_item(results, "recent_complaints") { |complaint| complaint["api_link"] = links.complaint(company_id, complaint["complaint_id"]) }
        each_item(results, "related_companies") { |company| company["api_link"] = links.company(company["company_id"]) }
        results
      end

      def companies_seen(results)
        info = results["company_info"]
        info ? [ info.values_at("company_id", "id") ] : []
      end
    end
  end
end
