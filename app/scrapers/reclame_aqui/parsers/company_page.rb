module ReclameAqui
  module Parsers
    # engine=reclame_aqui_company, from https://www.reclameaqui.com.br/empresa/{company_id}/
    #
    # Almost everything comes from the props of the page's Astro islands. The
    # "Desempenho" tabs only render the 6 month period, but the props carry all
    # five periods, so a single fetch covers every tab.
    class CompanyPage
      include Normalize

      PERIODS = {
        "SIX_MONTHS" => "six_months",
        "TWELVE_MONTHS" => "twelve_months",
        "LAST_YEAR" => "last_year",
        "PAST_LAST_YEAR" => "past_last_year",
        "LAST_THREE_YEARS" => "last_three_years"
      }.freeze

      NOT_FOUND = "Reclame Aqui hasn't returned any company for this company_id.".freeze

      def self.parse(html)
        new(Page.new(html)).parse
      end

      def initialize(page)
        @page = page
      end

      def parse
        return { error: NOT_FOUND } if @page.not_found?

        company = @page.island("ContactChannelsSectionIsland")&.dig("company")
        raise ParseError, "company island not found on #{@page.title.inspect}" if company.blank?

        prune(
          company_info: company_info(company),
          reputation: reputation(company["currentReputation"]),
          reputation_by_period: Array(company["reputation"]).filter_map { |period| reputation(period) },
          reputation_history:,
          ranking:,
          main_problems: main_problems(company["mainTags"]),
          recent_complaints:,
          related_companies:,
          alerts:,
          brands:,
          award: award(company["premioConfiguration"])
        )
      end

      private

      def company_info(company)
        about = @page.island_with("title", "cnpj", "timeOnPlatform") || {}
        segments = company["segments"] || {}
        main_segment = segments.dig("main", "shortname")

        prune(
          id: company["id"],
          company_id: company["shortname"],
          name: company["name"],
          description: text(about["description"] || company["description"]),
          logo: company["logo"],
          cover: company.dig("cover", "web"),
          website: company["siteUrl"],
          phones: Array(company["phones"]).filter_map { |phone| phone["number"].presence },
          social_networks: company["socialNetworks"]&.compact_blank&.symbolize_keys,
          address: address(company["address"]),
          cnpj: cnpj(about["cnpj"] || company["cnpj"]),
          cnpj_validated: company["cnpjValidated"],
          verified: company.dig("flags", "canShowRAVVerified") || company["ravLabel"] == "SHOW_VERIFIED",
          plan: company["plan"].presence,
          segment: segment(segments["main"]),
          subsegments: Array(segments["secondary"]).map { |secondary| segment(secondary, main_segment) },
          on_reclame_aqui_since: date(company["created"]),
          time_on_reclame_aqui: company["sinceTime"] || about["timeOnPlatform"],
          page_views: company["pageViews"],
          link: Urls.company(company["shortname"])
        )
      end

      def address(address)
        return nil if address.blank? || address.values_at("route", "city", "state").all?(&:blank?)

        location = address["location"] || {}
        prune(
          street: address["route"].presence,
          details: address["additionalDetails"].presence,
          neighborhood: address["neighborhood"].presence,
          city: address["city"].presence,
          state: address["state"].presence,
          zip_code: address["zipCode"].presence,
          gps_coordinates: prune(latitude: number(location["latitude"]), longitude: number(location["longitude"]))
        )
      end

      def segment(segment, main_shortname = nil)
        return nil if segment.blank?

        prune(
          id: segment["id"],
          name: segment["title"],
          shortname: segment["shortname"],
          complaints: segment["complainCount"],
          link: (Urls.segment(main_shortname || segment["shortname"], main_shortname && segment["shortname"]) if segment["hasPage"])
        )
      end

      def reputation(period)
        return nil if period.blank?

        prune(
          period: PERIODS.fetch(period["type"]) { period["type"].to_s.downcase },
          label: period_label(period),
          start_date: date(period["start"]),
          end_date: date(period["end"]),
          status: period["status"],
          status_label: status_label(period["status"]),
          score: number(period["finalScore"]),
          complaints: integer(period["complaints"]),
          answered: integer(period["answers"]),
          awaiting_response: integer(period["totalNotAnswered"] || period["awaiting"]),
          response_rate: number(period["answeredRate"]),
          solved_rate: number(period["solvedRate"]),
          deal_again_rate: number(period["dealAgainRate"]),
          evaluated: integer(period["ratings"]),
          consumer_score: number(period["consumerScore"]),
          average_response_time: response_time(period["averageAnswerTime"])
        )
      end

      # The two calendar-year tabs are labeled with the year itself; "Geral" is
      # the last three years, not all time.
      def period_label(period)
        case period["type"]
        when "SIX_MONTHS" then "6 meses"
        when "TWELVE_MONTHS" then "12 meses"
        when "LAST_THREE_YEARS" then "Geral"
        else period["start"].to_s.first(4).presence
        end
      end

      def response_time(seconds)
        seconds = number(seconds)
        seconds && { seconds: seconds.round, text: duration_text(seconds) }
      end

      def reputation_history
        Array(@page.island_with("data", "dictionary")&.dig("data")).map do |point|
          prune(month: month(point["date"]), label: point["date"], status: point["status"], status_label: status_label(point["status"]))
        end
      end

      def ranking
        position = @page.island("RankingIsland")&.dig("companyPosition")
        return nil if position.blank?

        prune(
          position: position["position"],
          type: position["type"]&.downcase,
          segment: position["segmentName"],
          link: Urls.segment(position["mainSegmentShortname"], position["secondarySegmentShortname"])
        )
      end

      def main_problems(tags)
        tags ||= @page.island_with("mainTags")&.dig("mainTags")
        return nil if tags.blank?

        prune(%i[categories problems products].index_with do |kind|
          Array(tags[kind.to_s]).map do |tag|
            prune(id: tag["id"], name: tag["description"], complaints: tag["count"], percentage: number(tag["proportion"]))
          end
        end)
      end

      # The complaint preview on the company page, already filtered by the tab the
      # site opens by default (usually "Não respondidas").
      def recent_complaints
        preview = @page.island_with("initialData", "defaultTab")
        return [] if preview.blank?

        preview["initialData"].each_with_index.map do |complaint, index|
          status, status_label = complaint_status(complaint["status"], evaluated: complaint["evaluated"], solved: complaint["solved"])
          prune(
            position: index + 1,
            complaint_id: complaint["id"],
            title: complaint["title"],
            snippet: text(complaint["description"])&.squish&.truncate(300, separator: " "),
            status:,
            status_label:,
            created_at: time(complaint["created"]),
            link: Urls.complaint(preview["shortname"], complaint["id"], complaint["url"])
          )
        end
      end

      def related_companies
        Array(@page.island("PeopleAlsoVisitedIsland")&.dig("relatedCompanies")).each_with_index.map do |company, index|
          prune(
            position: index + 1,
            company_id: company["shortname"],
            name: company["companyName"],
            logo: company["logo"],
            score: number(company["finalScore"]),
            status: company["status"],
            status_label: status_label(company["status"]),
            verified: company["canShowRAVVerified"],
            link: Urls.company(company["shortname"])
          )
        end
      end

      # Crisis notices the company pins to its page. The site renders each one
      # twice (mobile and desktop layouts).
      def alerts
        @page.islands
          .select { |island| island[:component] == "CompanyCrisisAlertIsland" }
          .map { |island| island[:props] }
          .uniq { |props| props.values_at("title", "html") }
          .map { |props| prune(type: props["alertType"]&.downcase, title: props["title"], text: text(props["html"])) }
      end

      def brands
        Array(@page.island_with("brands", "complaintUrl")&.dig("brands")).map do |brand|
          prune(id: brand["id"], name: brand["name"], logo: brand["logo"], link: Urls.absolute(brand["url"]))
        end
      end

      def award(config)
        metadata = config&.dig("metadata")
        return nil if metadata.blank? || metadata["status"].blank?

        prune(
          name: "Prêmio Reclame AQUI",
          status: metadata["status"].downcase,
          category: metadata.dig("category", "name"),
          link: Urls.absolute(metadata["votePath"])
        )
      end
    end
  end
end
