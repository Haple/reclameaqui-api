module ApplicationHelper
  # Renders `backticks` in engine parameter descriptions as <code>.
  def simple_code(text)
    safe_join(text.split("`").each_with_index.map { |part, index| index.odd? ? tag.code(part) : part })
  end

  # Examples carry the visitor's own key once they're signed in.
  def example_api_key
    authenticated? ? Current.user.api_key : "YOUR_API_KEY"
  end

  def brasilia(time)
    time&.in_time_zone("America/Sao_Paulo")&.strftime("%d %b %H:%M")
  end
end
