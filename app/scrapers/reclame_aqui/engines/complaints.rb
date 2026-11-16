module ReclameAqui
  module Engines
    class Complaints < Base
      # The tabs on the site's complaint list, and the filters each one sends.
      FILTERS = {
        "latest" => {},
        "not_answered" => { status: "PENDING", evaluated: "bool:false" },
        "answered" => { status: "ANSWERED", evaluated: "bool:false" },
        "evaluated" => { evaluated: "bool:true" },
        "solved" => { solved: "bool:true", evaluated: "bool:true" },
        "not_solved" => { solved: "bool:false", evaluated: "bool:true" }
      }.freeze

      MAX_NUM = 10

      engine "reclame_aqui_complaints",
        title: "Reclame Aqui Complaints API",
        summary: "A company's complaints, newest first, with the site's tabs as filters, keyword search and pagination."

      param :company_id, required: true, format: SLUG,
        description: "The company's slug, as in reclameaqui.com.br/empresa/`company_id`/."
      param :filter, default: "latest", allowed: FILTERS.keys,
        description: "Which tab to read: `latest`, `not_answered`, `answered`, `evaluated`, `solved` or `not_solved`."
      param :q, description: "Keyword search inside the company's complaints, like the site's \"Pesquise reclamações\" box."
      param :category_id, format: SLUG, description: "Only complaints in this category. IDs come from `filters.categories`."
      param :product_id, format: SLUG, description: "Only complaints about this product. IDs come from `filters.products`."
      param :problem_id, format: SLUG, description: "Only complaints about this problem. IDs come from `filters.problems`."
      param :start, default: "0", format: /\A\d+\z/, description: "Result offset for pagination: `0` is the first page, `10` the second."
      param :num, default: "10", format: /\A\d+\z/, description: "Results per page, `1` to `10`. The site's API returns nothing above 10."

      # The complaint API takes the internal company id ("29260",
      # "fQcd3AN0mGTu3Yi1"), not the slug, so it is resolved first.
      def prepare(client)
        @internal_id = KnownCompany.resolve(params["company_id"], client:)
      end

      def source_url
        filters = FILTERS.fetch(params["filter"]).merge(
          category: params["category_id"], productType: params["product_id"], problemType: params["problem_id"]
        )
        Urls.complaints(company: @internal_id, num:, start:, query: params["q"], filters:)
      end

      def parse(body)
        Parsers::Complaints.parse(JsonDocument.parse(body), start:).deep_stringify_keys
      end

      def decorate(results, links)
        each_item(results, "complaints") do |complaint|
          complaint["api_link"] = links.complaint(complaint.dig("company", "company_id") || params["company_id"], complaint["complaint_id"])
        end
        results["pagination"] = pagination(results.dig("search_information", "total_results").to_i, links) if results["complaints"].present?
        results
      end

      def companies_seen(results)
        Array(results["complaints"]).filter_map { |complaint| complaint["company"]&.values_at("company_id", "id") }.uniq
      end

      private

      def num
        params["num"].to_i.clamp(1, MAX_NUM)
      end

      def start
        params["start"].to_i
      end

      # Same shape as SerpApi's serpapi_pagination: links for the next and
      # previous pages plus a window of numbered pages around the current one.
      def pagination(total, links)
        current = (start / num) + 1
        last = [ (total.to_f / num).ceil, 1 ].max
        page_link = ->(page) { links.search(search_parameters.merge("start" => ((page - 1) * num).to_s)) }

        window = ([ current - 2, 1 ].max..[ current + 2, last ].min).reject { |page| page == current }
        {
          "current" => current,
          "previous" => (page_link.call(current - 1) if current > 1),
          "next" => (page_link.call(current + 1) if current < last),
          "other_pages" => window.to_h { |page| [ page.to_s, page_link.call(page) ] }
        }.compact
      end
    end
  end
end
