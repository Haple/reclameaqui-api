class SearchesController < ApplicationController
  # Stored pages are served under a sandbox CSP: no scripts, no same-origin
  # access, styles and images still load from Reclame Aqui.
  RAW_CSP = "sandbox; default-src 'none'; style-src https: 'unsafe-inline'; img-src https: data:; font-src https: data:".freeze

  rate_limit to: 30, within: 10.minutes, only: :run,
    with: -> { render json: { error: "Too many searches from this address. Try again in a few minutes." }, status: :too_many_requests }

  rescue_from Mongoid::Errors::DocumentNotFound, BSON::Error::InvalidObjectId do
    render json: { error: "Search not found." }, status: :not_found
  end

  # GET /search.json?engine=...
  def run
    engine = ReclameAqui::Engines.build(request.query_parameters)
    search = SearchRunner.new.call(engine, no_cache: flag?(:no_cache), async: flag?(:async))

    respond_to do |format|
      format.json { render json: SearchPresenter.new(search, links) }
      format.html { redirect_to archived_search_path(search, format: :html) }
    end
  rescue ReclameAqui::Engines::InvalidParams => e
    render json: { error: e.message }, status: :bad_request
  rescue SearchRunner::BudgetExceeded => e
    render json: { error: e.message }, status: :too_many_requests
  end

  # GET /searches/:id.json is the Search Archive API; .html is the raw_html_file.
  def show
    search = Search.find(params[:id])

    respond_to do |format|
      format.json { render json: SearchPresenter.new(search, links) }
      format.html { send_raw(search.raw_response) }
    end
  end

  # GET /searches/:id/preview, the sanitized page the playground displays.
  def preview
    raw = Search.find(params[:id]).raw_response
    return head :not_found unless raw

    send_data RawPreview.new(raw).to_html, type: "text/html; charset=utf-8", disposition: "inline"
  end

  private

  def send_raw(raw)
    return head :not_found unless raw

    response.headers["Content-Security-Policy"] = RAW_CSP
    if raw.json?
      send_data JSON.pretty_generate(ReclameAqui::JsonDocument.parse(raw.body)), type: "application/json", disposition: "inline"
    else
      send_data raw.body, type: "text/html; charset=utf-8", disposition: "inline"
    end
  end

  def flag?(name)
    ActiveModel::Type::Boolean.new.cast(params[name]) || false
  end

  def links
    ApiLinks.new(request.base_url)
  end
end
