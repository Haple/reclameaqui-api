# The stored page, made safe to show inside the playground: scripts and event
# handlers removed, and a <base> so Reclame Aqui's own stylesheets still load.
# The playground puts it in an <iframe sandbox="allow-same-origin"> so it can
# outline the element a JSON key came from.
class RawPreview
  REMOVED = "script, noscript, iframe, object, embed, link[rel=preload], link[rel=modulepreload], meta[http-equiv]".freeze

  def initialize(raw_response)
    @raw_response = raw_response
  end

  def to_html
    return json_preview if @raw_response.json?

    doc = Nokogiri::HTML5(@raw_response.body)
    doc.css(REMOVED).each(&:remove)
    doc.xpath("//@*[starts-with(name(), 'on')]").each(&:remove)
    head = doc.at_css("head") || doc.root.prepend_child(doc.create_element("head"))
    head.prepend_child(doc.create_element("base", href: "#{ReclameAqui::Urls::SITE}/"))
    doc.to_html
  end

  private

  def json_preview
    json = JSON.pretty_generate(ReclameAqui::JsonDocument.parse(@raw_response.body))
    "<!doctype html><meta charset=utf-8><pre style=\"font:12px/1.5 ui-monospace,monospace;white-space:pre-wrap;margin:16px\">#{ERB::Util.html_escape(json)}</pre>"
  end
end
