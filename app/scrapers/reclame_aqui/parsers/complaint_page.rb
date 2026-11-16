module ReclameAqui
  module Parsers
    # engine=reclame_aqui_complaint, from https://www.reclameaqui.com.br/{company_id}/_{complaint_id}/
    class ComplaintPage
      include Normalize

      INTERACTION_TYPES = {
        "ANSWER" => "company_answer",
        "REPLICATION" => "consumer_reply",
        "REPLICA" => "consumer_reply",
        "FINAL_ANSWER" => "final_consideration"
      }.freeze

      NOT_FOUND = "Reclame Aqui hasn't returned any complaint for this complaint_id.".freeze

      def self.parse(html)
        new(Page.new(html)).parse
      end

      def initialize(page)
        @page = page
      end

      def parse
        return { error: NOT_FOUND } if @page.not_found?

        props = @page.island("ComplaintReadingClient")
        complaint = props&.dig("complaint")
        raise ParseError, "complaint island not found on #{@page.title.inspect}" if complaint.blank?

        prune(
          complaint: complaint_details(complaint, props["fullUrl"]),
          interactions: Array(complaint["interactions"]).map { |interaction| interaction(interaction) },
          company: company(props["company"], props.dig("companySegments", "companyPosition")),
          similar_complaints:
        )
      end

      private

      def complaint_details(complaint, link)
        status, status_label = complaint_status(complaint["status"], evaluated: complaint["evaluated"], solved: complaint["solved"])
        prune(
          complaint_id: complaint["id"],
          title: complaint["title"],
          description: text(complaint["description"]),
          status:,
          status_label:,
          solved: complaint["solved"],
          evaluated: complaint["evaluated"],
          rating: (number(complaint["score"])&.to_f if complaint["evaluated"]),
          deal_again: (complaint["dealAgain"] if complaint["evaluated"]),
          created_at: time(complaint["created"]),
          location: prune(city: complaint["userCity"].presence, state: complaint["userState"].presence),
          category: tag(complaint["category"]),
          problem: tag(complaint["problemType"]),
          product: tag(complaint["productType"]),
          additional_info: complaint["additionalInfo"].presence,
          link: link.presence || Urls.complaint(complaint["companyShortname"], complaint["id"], complaint["url"])
        )
      end

      def tag(tag)
        tag.present? ? prune(id: tag["id"], name: tag["name"]) : nil
      end

      def interaction(interaction)
        prune(
          type: INTERACTION_TYPES.fetch(interaction["type"]) { interaction["type"].to_s.downcase },
          message: text(interaction["message"]),
          created_at: time(interaction["created"])
        )
      end

      def company(company, position)
        return nil if company.blank?

        index = java_map(company["companyIndex6Months"])
        prune(
          id: company["id"],
          company_id: company["shortname"],
          name: company["companyName"],
          logo: company.dig("logo", "path"),
          website: company["urlSite"].presence,
          reputation: prune(
            period: "six_months",
            status: index["status"],
            status_label: status_label(index["status"]),
            score: number(index["finalScore"]),
            solved_rate: number(index["solvedPercentual"])
          ),
          ranking: (prune(position: position["position"], type: position["type"]&.downcase, segment: position["segmentName"]) if position.present?),
          link: Urls.company(company["shortname"])
        )
      end

      # companyIndex6Months is a Java Map#toString() that leaked into the props:
      # "{averageAnswerTime=592736.0, finalScore=8.4, ..., status=RA1000}".
      def java_map(value)
        value.to_s.delete_prefix("{").delete_suffix("}").split(", ").to_h { |pair| pair.split("=", 2) }
      end

      def similar_complaints
        props = @page.island("ComplaintReadSimilarComplaints")
        Array(props&.dig("items")).each_with_index.map do |item, index|
          status, status_label = complaint_status(item["status"], evaluated: item["evaluated"], solved: item["solved"])
          prune(
            position: index + 1,
            complaint_id: item["id"],
            title: item["title"],
            status:,
            status_label:,
            created_at: time(item["createdIso"]),
            link: Urls.complaint(props["companyShortname"], item["id"], item["url"])
          )
        end
      end
    end
  end
end
