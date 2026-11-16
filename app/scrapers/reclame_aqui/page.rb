module ReclameAqui
  # A fetched Reclame Aqui HTML page plus the structured data embedded in it:
  # Astro island props and JSON-LD.
  class Page
    attr_reader :doc

    def initialize(html)
      @doc = Nokogiri::HTML5(html)
    end

    def title
      doc.at_css("title")&.text&.strip
    end

    def not_found?
      title.to_s.include?("404")
    end

    # Island file names carry a build hash ("ContactChannelsSectionIsland.DTITmigQ.js")
    # that changes on every deploy, so islands are matched by component name or by
    # the keys their props hold.
    def islands
      @islands ||= doc.css("astro-island[props]").filter_map do |node|
        props = AstroProps.parse(node["props"])
        component = node["component-url"].to_s[%r{([^/]+?)\.[\w-]+\.js\z}, 1]
        { component:, props:, node: }
      rescue JSON::ParserError
        nil
      end
    end

    def island(component)
      islands.find { |island| island[:component] == component }&.dig(:props)
    end

    def island_with(*keys)
      islands.find { |island| keys.all? { |key| island[:props].key?(key) } }&.dig(:props)
    end

    def json_ld(type)
      doc.css('script[type="application/ld+json"]').each do |script|
        Array(JSON.parse(script.text)).each do |item|
          return item if item["@type"] == type
        end
      rescue JSON::ParserError
        next
      end
      nil
    end

    def section(name)
      doc.at_css(%([data-company-home-section="#{name}"]))
    end
  end
end
