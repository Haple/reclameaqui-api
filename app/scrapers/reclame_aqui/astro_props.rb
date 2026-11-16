module ReclameAqui
  # Decodes the props Astro serializes into <astro-island props="...">.
  #
  # Every value is a [type, payload] tuple (astro/src/runtime/server/serialize.ts):
  # objects are [0, {key => tuple}], arrays are [1, [tuple, ...]], and a bare [0]
  # means undefined. Decoding them gives back the exact data the page was rendered
  # from, which is sturdier to parse than the markup built on top of it.
  module AstroProps
    VALUE = 0
    ARRAY = 1
    MAP = 4
    SET = 5
    BIGINT = 6
    INFINITY = 11

    module_function

    def parse(raw)
      decode_object(JSON.parse(raw))
    end

    def decode(tuple)
      return tuple unless tuple.is_a?(Array)
      return nil if tuple.size < 2

      type, payload = tuple
      case type
      when VALUE then payload.is_a?(Hash) ? decode_object(payload) : payload
      when ARRAY, SET then payload.map { |item| decode(item) }
      when MAP then payload.map { |pair| decode(pair) }.to_h
      when BIGINT then payload.to_i
      when INFINITY then payload.to_i.negative? ? -Float::INFINITY : Float::INFINITY
      else payload # RegExp source, Date ISO string, URL string, typed arrays
      end
    end

    def decode_object(hash)
      hash.transform_values { |tuple| decode(tuple) }
    end
  end
end
