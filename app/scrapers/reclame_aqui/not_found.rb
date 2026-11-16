module ReclameAqui
  # Reclame Aqui answered with its 404 template: no company or complaint under
  # that id. Reported like SerpApi reports an empty result, not as a failure.
  class NotFound < StandardError; end
end
