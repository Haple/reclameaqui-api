class PostsController < ApplicationController
  POSTS = Rails.root.join("content/posts")

  def show
    path = POSTS.join("#{params[:slug]}.md")
    raise ActionController::RoutingError, "No such post" unless params[:slug].match?(/\A[a-z0-9-]+\z/) && path.exist?

    markdown = path.read
    @title = markdown[/\A# (.+)$/, 1]
    @html = Commonmarker.to_html(markdown, options: { extension: { table: true, autolink: true, strikethrough: true, header_ids: "" } }, plugins: { syntax_highlighter: nil })
  end
end
