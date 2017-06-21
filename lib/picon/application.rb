require 'rmagick'
require 'sinatra/json'
require 'digest/sha1'
require 'syslog/logger'

module Picon
  class Application < Sinatra::Base
    set :public_folder, File.join(ROOT_DIR, 'www')

    def initialize
      super
      @logger = Syslog::Logger.new('picon')
    end

    before do
      @message = {request:{path: request.path}, response:{}}
      @status = 200
      @type = :json
    end

    after do
      @message[:request][:params] = params
      @message[:response][:status] = @status
      @message[:response][:type] = @type
      if (@status < 300)
        @logger.info(json(@message))
      else
        @logger.error(json(@message))
      end
      content_type @type
      status @status
    end

    get '/convert' do
      unless params['path']
        @status = 400
        @message[:error] = 'pathが未指定です。'
        return json(@message)
      end

      unless File.exist?(params['path'])
        @status = 404
        @message[:error] = "#{params['path']}が見つかりません。"
        return json(@message)
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
          @status = 400
          @message[:error] = e.message
          return json(@message)
        end
      end

      @message[:response][:sent] = File.basename(dest)
      @type = :png
      return File.read(dest)
    end

    not_found do
      @status = 404
      return json(@message)
    end

    error do
      @status = 500
      return json(@message)
    end
  end
end
