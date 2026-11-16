# Renders a search in SerpApi's response layout: search_metadata, then
# search_parameters, then the engine's results.
class SearchPresenter
  def initialize(search, links)
    @search = search
    @links = links
  end

  def as_json(*)
    body = { "search_metadata" => metadata, "search_parameters" => @search.parameters }
    return body if @search.processing?
    return body.merge("error" => @search.error) if @search.status == "Error"

    engine = ReclameAqui::Engines.build(@search.parameters)
    body.merge(engine.decorate(@search.results.deep_dup, @links)).merge("error" => @search.error).compact
  end

  private

  def metadata
    id = @search.id.to_s
    {
      "id" => id,
      "status" => @search.status,
      "json_endpoint" => @links.archive(id, "json"),
      "created_at" => timestamp(@search.created_at),
      "processed_at" => timestamp(@search.processed_at),
      "reclame_aqui_url" => @search.source_url,
      "raw_html_file" => (@links.archive(id, "html") if @search.source_url),
      "total_time_taken" => total_time_taken
    }.compact
  end

  def total_time_taken
    milliseconds = @search.timings["total_ms"]
    milliseconds && (milliseconds / 1000.0).round(2)
  end

  def timestamp(time)
    time&.utc&.strftime("%Y-%m-%d %H:%M:%S UTC")
  end
end
