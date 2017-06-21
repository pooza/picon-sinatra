require 'rmagick'
require 'sinatra/json'
require 'digest/sha1'
require 'syslog/logger'

module Picon
  class Application < Sinatra::Base
    def initialize
      super
      @logger = Syslog::Logger.new('picon')
    end

    get '/convert' do
      unless params['path']
        @logger.error(json({error: 'pathが未指定です。'}))
        status 404
        return
      end

      unless File.exist?(params['path'])
        @logger.error(json({error: "#{params['path']}が見つかりません。"}))
        status 404
        return
      end

      params['pixel'] ||= 100
      params['background_color'] ||= 'white'
      digest = Digest::SHA1.hexdigest([
        File.read(params['path']),
        params['pixel'],
        params['background_color'],
      ].join(':'))
      dest = File.join(ROOT_DIR, "images/#{digest}.png")

      unless File.exist?(dest)
        begin
          pixel = params['pixel'].to_i
          image = Magick::Image.new(pixel, pixel)
          image.background_color = params['background_color']
          image.composite!(
            Magick::Image.read(params['path']).first.resize_to_fit(pixel),
            Magick::CenterGravity,
            Magick::OverCompositeOp
          )
          image.write(dest)
          @logger.info(json({writtern: dest}))
        rescue => e
          data = {status: 400, message: e.message}.merge(params)
          @logger.error(json(data))
          status 400
          return json(data)
        end
      end

      @logger.info(json({sent: File.basename(dest)}))
      content_type :png
      return File.read(dest)
    end

    not_found do
      status 404
      return json({status: 404})
    end

    error do
      status 500
      return json({status: 500})
    end
  end
end
