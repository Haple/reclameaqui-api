module ReclameAqui
  module Parsers
    # engine=reclame_aqui_complaints, from the JSON the site's complaint list loads:
    # iosearch.reclameaqui.com.br/.../query/companyComplains/{num}/{start}?company={id}
    class Complaints
      include Normalize

      SNIPPET_LENGTH = 300

      def self.parse(json, start: 0)
        new(json, start:).parse
      end

      def initialize(json, start: 0)
        @json = json
        @start = start
      end

      def parse
        list = @json.dig("complainResult", "complains")
        raise ParseError, "complainResult.complains not found" unless list.is_a?(Hash)

        prune(
          search_information: { total_results: list["count"].to_i },
          complaints: Array(list["data"]).each_with_index.map { |complaint, index| complaint(complaint, @start + index + 1) },
          filters: filters(list)
        )
      end

      private

      # Keyword searches return the description cut at 130 characters and the full
      # text only in descriptionMasked, which is also the version with CPFs and
      # card numbers starred out, as the site displays it. Masked text is preferred.
      def complaint(complaint, position)
        status, status_label = complaint_status(complaint["status"], evaluated: complaint["evaluated"], solved: complaint["solved"])
        prune(
          position:,
          complaint_id: complaint["id"],
          title: complaint["titleMasked"].presence || complaint["title"],
          snippet: text(complaint["descriptionMasked"].presence || complaint["description"])&.squish&.truncate(SNIPPET_LENGTH, separator: " "),
          status:,
          status_label:,
          solved: complaint["solved"],
          evaluated: complaint["evaluated"],
          rating: (number(complaint["score"])&.to_f if complaint["evaluated"]),
          deal_again: (complaint["dealAgain"] if complaint["evaluated"]),
          created_at: time(complaint["created"]),
          updated_at: time(complaint["modified"]),
          location: prune(city: complaint["userCity"].presence, state: complaint["userState"].presence),
          category_id: complaint["category"],
          product_id: complaint["productType"],
          problem_id: complaint["problemType"],
          company: prune(id: complaint["company"], company_id: complaint["companyShortname"], name: complaint["companyName"]),
          link: Urls.complaint(complaint["companyShortname"], complaint["id"], complaint["url"])
        )
      end

      # Facet counts for the whole result set, usable as category_id, product_id
      # and problem_id on the next request.
      def filters(list)
        prune(%i[categories products problems].index_with do |kind|
          Array(list[kind.to_s]).map { |facet| prune(id: facet["id"], name: facet["name"], complaints: facet["count"]) }
        end)
      end
    end
  end
end
