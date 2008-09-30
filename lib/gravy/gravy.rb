module Gravy 
  class << self
    def logger=(logr)
      @logger = logr
    end
    
    def logger
      unless @logger
        @logger = Logger.new(STDOUT)
        @logger.level = Logger::INFO
      end
      @logger
    end
  end
  
  module Utensils
    class << self
      def content_type_for(filepath)
        # From mimetype_fu!
        content_type = `file --mime -br #{filepath}`
        content_type = content_type.gsub(/^.*: */,"")
        content_type = content_type.gsub(/;.*$/,"")
        content_type = content_type.gsub(/,.*$/,"").chomp
      end
      
      def parse(res)
        JSON.parse res
      end
    end
  end

  class Attachment
    include Utensils
    
    attr_reader :document, :name, :url
    attr_accessor :content_type, :content_length, :data
    
    def initialize(params={})
      @document = params[:document]
      @name = params[:name]
      @content_type = params[:content_type]
      @content_length = params[:content_length].to_s
      @data = params[:data]
    end
    
    def content_length=(len)
      len.to_s
    end
  end
  
  class StandaloneAttachment < Attachment
    def initialize(params={})
      super
    end
    
    def url
      "#{@document.url}#{@name}"
    end
    
    def create
      if @document.has_rev?
        attach_url = "#{document.url}#{@name}?rev=#{@document.rev}"
      else
        attach_url = "#{document.url}#{@name}"
      end

      res = RestClient.put( attach_url, 
                            @data, 
                            {:content_type=>@content_type, 
                            :content_length=>@content_length} )
      results = Utensils.parse res
      Gravy.logger.debug results
      @document.id, @document.rev = results['id'], results['rev'] if results['ok']
      self
    end
    
    def delete
      if @document.has_rev?
        attach_url = "#{document.url}#{@name}?rev=#{@document.rev}"
      else
        attach_url = "#{document.url}#{@name}"
      end

      res = RestClient.delete( attach_url, 
                               {:content_type=>@content_type, 
                               :content_length=>@content_length} )
      results = Utensils.parse res
      Gravy.logger.debug results
      @document.id, @document.rev = results['id'], results['rev'] if results['ok']
      nil
    end
  end

  class Document
    include Utensils
    
    attr_reader :database
    attr_accessor :data, :id, :rev, :url
    
    def initialize(params={})
      @database = params[:database]
      @data = params[:data]
      @id = @data['_id']
      @rev = @data['_rev']
    end
    
    def url(rev=nil)
      if has_id?
        doc_url = "#{@database.url}#{@id}"
        if rev
          "#{doc_url}?rev=#{rev}"
        else
          "#{doc_url}/"
        end
      else
        nil
      end
    end
    
    def has_id?
      @id.nil? ? false : true
    end
  
    def has_rev?
      @rev.nil? ? false : true
    end
  
    def to_json
      data = @data
      data.delete '_id' unless has_id?
      data.delete '_rev' unless has_rev?
      data.to_json
    end
  
    def create
      if has_id?
        res = RestClient.put("#{database.url}#{@id}", 
                                  to_json, 
                                  {:content_type=>"application/json"})
      else
        res = RestClient.post(@database.url, 
                                   to_json, 
                                   {:content_type=>"application/json"})
      end
      
      results = Utensils.parse res
      Gravy.logger.debug results
      @id, @rev = results['id'], results['rev'] if results['ok']
      self
    end
    
    def create_standalone_attachment(name, content_type, content_length, data)
      StandaloneAttachment.new({:document=>self,
                                :name=>name, 
                                :content_type=>content_type, 
                                :content_length=>content_length, 
                                :data=>data}).create
    end
  end
  
  class Database
    include Utensils
    
    attr_reader :node, :name, :url
    
    def initialize(config={})
      @node = config[:node]
      @name = config[:name]
      @url = "#{@node.url}#{@name}/"
    end
  
    def create  
      res = RestClient.put(@url, nil, nil)
      results = Utensils.parse res
      Gravy.logger.debug results
      self if results['ok']
    rescue RestClient::RequestFailed => e
      Gravy.logger.error "Database#create error."
      Gravy.logger.error e.backtrace.inspect
      raise "Database#create error: " + e.to_s
    end

    def delete
      res = RestClient.delete(@url, nil)
      results = Utensils.parse res
      Gravy.logger.debug results
    rescue RestClient::ResourceNotFound => e
      Gravy.logger.error "Database#delete error. Database not found."
      Gravy.logger.error e.backtrace.inspect
      raise "Database#delete error: Database not found."
    end

    def create_document(data)
      Document.new({:database=>self,:data=>data}).create
    end
  end
  
  class Node
    include Utensils
    
    attr_reader :protocol, :address, :port, :url
    
    def initialize(config={})
      @protocol = config[:protocol] || "http"
      @address = config[:address] || "localhost"
      @port = config[:port] || 5984
      @url = "#{@protocol}://#{@address}:#{@port}/"
    end
  
    def create_database(name)
      Database.new({:node=>self,:name=>name}).create
    end
    
    def delete_database(name)
      Database.new({:node=>self,:name=>name}).delete
    end
  end
  
end