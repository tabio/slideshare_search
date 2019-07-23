require 'slideshare_search/version'
require 'digest'
require 'net/http'
require 'nokogiri'
require 'openssl'
require 'pry'
require 'time'

module SlideshareSearch
  class Error < StandardError; end

  class Client
    attr_reader :api_key, :secret_key, :target_date, :errors

    SEARCH_URL = 'https://www.slideshare.net/api/2/search_slideshows'

    def initialize(api_key, secret_key, target_date = nil)
      @api_key     = api_key
      @secret_key  = secret_key
      @target_date = target_date ? Time.parse(target_date) : nil
      @errors      = []
    end

    def search(query)
      uri       = URI.parse(SEARCH_URL)
      uri.query = URI.encode_www_form(search_params(query))

      res = Net::HTTP.get_response(uri)
      xml = Nokogiri::XML(res.body)

      Response.get_slides(xml, target_date)
    end

    private

    def search_params(query)
      now_time = Time.now.to_i
      hash     = Digest::SHA1.hexdigest("#{secret_key}#{now_time}")
      params   = { api_key: api_key, ts: now_time, hash: hash, lang: 'ja', detailed: 1, sort: 'latest', upload_date: 'week', q: query }
      params
    end
  end

  class Response
    attr_reader :title, :description, :url, :tags, :num_views, :created, :updated

    class << self
      def get_slides(xml, target_date)
        nodes = xml.xpath('Slideshows/Slideshow')
        nodes.map do |element|
          response = Response.new(element)
          target_date.nil? || (response.created >= target_date) ? response : nil
        end.compact
      end
    end

    def initialize(element)
      @title       = element.xpath('Title').text
      @description = element.xpath('Description').text
      @url         = element.xpath('URL').text
      @tags        = element.xpath('Tags/Tag').map { |node| node.text }
      @num_views   = element.xpath('NumViews').text.to_i
      @created     = Time.parse(element.xpath('Created').text).getlocal
      @updated     = Time.parse(element.xpath('Updated').text).getlocal
    end
  end
end
