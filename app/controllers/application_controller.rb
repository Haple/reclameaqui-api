class ApplicationController < ActionController::Base
  include Authentication

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  private

  # Behind Cloudflare every request reaches the app from the tunnel on
  # localhost; Cloudflare passes the visitor's address in this header.
  def client_ip
    request.headers["CF-Connecting-IP"].presence || request.remote_ip
  end
end
