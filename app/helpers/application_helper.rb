module ApplicationHelper
  # Renders `backticks` in engine parameter descriptions as <code>.
  def simple_code(text)
    safe_join(text.split("`").each_with_index.map { |part, index| index.odd? ? tag.code(part) : part })
  end
end
