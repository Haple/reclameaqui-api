# Backs async=true: the request returns at once with status "Processing" and
# the client polls the search's json_endpoint.
class SearchJob < ApplicationJob
  def perform(search_id)
    SearchRunner.new.perform(Search.find(search_id))
  end
end
