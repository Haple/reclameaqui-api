module ReclameAqui
  module Engines
    class Complaint < Base
      engine "reclame_aqui_complaint",
        title: "Reclame Aqui Complaint API",
        summary: "One complaint in full: the consumer's text, every company answer and reply, the final rating and similar complaints."

      param :company_id, required: true, format: SLUG,
        description: "The slug of the company the complaint was filed against."
      param :complaint_id, required: true, format: SLUG,
        description: "The complaint's id, the part after the last underscore in its URL. Returned by the Complaints API."

      XRAY = {
        "complaint" => '[data-testid="complaint-reading-container"]',
        "complaint.title" => '[data-testid="complaint-title"]',
        "complaint.description" => '[data-testid="complaint-description"]',
        "complaint.rating" => '[data-testid="evaluation-score"]',
        "complaint.deal_again" => '[data-testid="evaluation-deal-again"]',
        "complaint.solved" => '[data-testid="evaluation-solved"]',
        "interactions" => '[data-testid="complaint-read-mobile-thread"]',
        "company" => '[data-testid="compact-company-info"]',
        "similar_complaints" => '[data-testid="complaint-read-similar-complaints"]'
      }.freeze

      def source_url
        Urls.complaint(params["company_id"], params["complaint_id"])
      end

      def parse(body)
        Parsers::ComplaintPage.parse(body).deep_stringify_keys
      end

      def decorate(results, links)
        company = results["company"]
        company["api_link"] = links.company(company["company_id"]) if company
        each_item(results, "similar_complaints") do |complaint|
          complaint["api_link"] = links.complaint(company&.dig("company_id") || params["company_id"], complaint["complaint_id"])
        end
        results
      end

      def companies_seen(results)
        company = results["company"]
        company ? [ company.values_at("company_id", "id") ] : []
      end
    end
  end
end
