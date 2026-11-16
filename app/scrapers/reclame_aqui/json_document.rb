module ReclameAqui
  # Browser Rendering returns the DOM Chrome built for a response, so a JSON
  # endpoint comes back wrapped in Chrome's viewer: <body><pre>{...}</pre></body>.
  module JsonDocument
    module_function

    def parse(body)
      text = body.to_s.lstrip
      text = Nokogiri::HTML5(text).at_css("pre")&.text.to_s unless text.start_with?("{", "[")
      raise ParseError, "empty JSON response" if text.blank?

      JSON.parse(text)
    rescue JSON::ParserError => e
      raise ParseError, "invalid JSON response: #{e.message}"
    end
  end
end
