require 'yaml'
require 'rmagick'
require 'sinatra/json'
require 'digest/sha1'
require 'syslog/logger'

module Picon
  class Application < Sinatra::Base
    set :public_folder, File.join(ROOT_DIR, 'www')

    def initialize
      super
      @config = YAML.load_file(File.join(ROOT_DIR, 'config/picon.yaml'))
      @config['thin'] = YAML.load_file(File.join(ROOT_DIR, 'config/thin.yaml'))
      @logger = Syslog::Logger.new(@config['application']['name'])
      @logger.info(
        'starting %s %s (port %d)'%([
          @config['application']['name'],
          @config['application']['version'],
          @config['thin']['port'],
        ])
      )
    end

    before do
      @message = {request:{path: request.path}, response:{}}
      @status = 200
      @type = :json
    end

    after do
      @message[:request][:params] = params.to_h
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

    post '/resize' do
      params[:width] ||= 100
      params[:height] ||= 100
      params[:cackground_color] ||= 'white'
      digest = Digest::SHA1.hexdigest([
        '/resize',
        File.read(params[:file][:tempfile]),
        params[:width],
        params[:height],
        params[:cackground_color],
      ].join(':'))
      dest = File.join(ROOT_DIR, "images/#{digest}.png")

      unless File.exist?(dest)
        begin
          width = params[:width].to_i
          height = params[:height].to_i
          color = params[:cackground_color]
          constant image = Magick::Image.new(width, height) do
            self.background_color = color
          end
          image.composite!(
            Magick::Image.from_blob(
              File.read([:file][:tempfile])
            ).first.resize_to_fit(width, height),
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

    post '/resize_width' do
      params[:width] ||= 100
      digest = Digest::SHA1.hexdigest([
        '/resize_width',
        File.read(params[:file][:tempfile]),
        params[:width],
      ].join(':'))
      dest = File.join(ROOT_DIR, "images/#{digest}.png")

      unless File.exist?(dest)
        begin
          width = params[:width].to_i
          image = Magick::Image.from_blob(
            File.read(params[:file][:tempfile])
          ).first
          image.resize!(width, image.rows * width / image.columns)
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
