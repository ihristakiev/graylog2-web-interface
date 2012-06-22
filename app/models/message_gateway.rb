class UnsupportedResultType < StandardError; end

# Overwrite to allow setting of document type
#  - https://github.com/karmi/tire/issues/96
module Tire::Model::Naming::ClassMethods
  def document_type(name=nil)
    @document_type = name if name
    @document_type || klass.model_name.singular
  end
end

class Tire::Search::Query
  def wildcard(field, value, options={})
    query = { field => {:wildcard => value}.update(options) }
    @value = { :wildcard => query }
  end
end

# monkey patch, shmonkey patch (Raising Timeout from 60s to no timeout)
module Tire::HTTP::Client
  class RestClient
    def self.get(url, data=nil)
      perform ::RestClient::Request.new(:method => :get, :url => url, :payload => data, :timeout => -1).execute
    rescue ::RestClient::Exception => e
      Tire::HTTP::Response.new e.http_body, e.http_code
    end
  end
end

# XXX ELASTIC: try curb as HTTP adapter for tire. reported to be faster: https://gist.github.com/1204159
class MessageGateway
  include Tire::Model::Search
  include Mongoid::Document

  # used if not set in config
  DEFAULT_INDEX_NAME = "graylog2"

  # XXX ELASTIC: sucks.
  if Rails.env == "test"
    INDEX_NAME = "graylog2_test"
  else
    config_index = Configuration.indexer_index_name
    config_index.blank? ? INDEX_NAME = DEFAULT_INDEX_NAME : INDEX_NAME = config_index
  end

  TYPE_NAME = "message"
  Tire.configure {logger 'ES.log'}
  
  index_name(INDEX_NAME)
  document_type(TYPE_NAME)

  @index = Tire.index(INDEX_NAME)
  @default_query_options = { :sort => "created_at desc" }

  def self.all_paginated(page = 1, last_poll_time = 0, less_than = Time.now.utc.to_i)
    r = search(pagination_options(page).merge(@default_query_options)) do
      query do
        boolean do
          must { range(:created_at, :gt => last_poll_time, :lt => less_than) }
        end
      end
    end
    
    wrap(r)
  end

  def self.all_since(last_poll_time = Time.now.utc)
    r = search(@default_query_options) do
      query do
        boolean do
          must { range(:created_at, :gt => last_poll_time, :lt => Time.now.utc.to_i) }
        end
      end
    end

    wrap(r)
  end

  def self.all_of_stream_paginated(stream_id, page = 1, last_poll_time = Time.now.utc.to_i - 1)
    r = search(pagination_options(page).merge(@default_query_options)) do
      query do
        boolean do
          # Stream
          must { term(:streams, stream_id) }
          
          # Timeframe.
          must { range(:created_at, :gt => last_poll_time, :lt => Time.now.utc.to_i) }
        end
      end
    end    
    
    wrap(r)
  end

  def self.all_of_host_paginated(hostname, page = 1, last_poll_time = Time.now.utc.to_i - 1)
    r = search(pagination_options(page).merge(@default_query_options)) do
      query do
        boolean do
          # Host
          must { term(:host, hostname) }
          
          # Timeframe.
          must { range(:created_at, :gt => last_poll_time, :lt => Time.now.utc.to_i) }
        end
      end
    end    
    
    wrap(r)   
end

  def self.retrieve_by_id(id)
    wrap @index.retrieve(TYPE_NAME, id)
  end

  def self.dynamic_search(what, with_default_query_options = false)
    what = what.merge({:sort => { :created_at => :desc }}) if with_default_query_options
    wrap Tire.search(INDEX_NAME, what)
  end

  def self.dynamic_distribution(target, query)
    result = Array.new

    query[:facets] = {
      "distribution_result" => {
        "terms" => {
          "field" => target,
          "all_terms" => true,
          "size" => 99999
        }
      }
    }

    r = Tire.search(INDEX_NAME, query)

    # [{"term"=>"baz.example.org", "count"=>4}, {"term"=>"bar.example.com", "count"=>3}]
    r.facets["distribution_result"]["terms"].each do |r|
      next if r["count"] == 0 # ES returns the count for *every* field. Skip those that had no matches.
      result << { :distinct => r["term"], :count => r["count"] }
    end

    return result
  end

  def self.all_by_quickfilter(filters, page = 1, opts = {}, last_poll_time = 0, extra_options = {}, less_than = Time.now.utc.to_f)
    r = search pagination_options(page).merge(@default_query_options).merge(extra_options) do
      query do
        boolean do
          
          # Short message  
          if !filters[:message_case].blank?
            filters[:message].split(" ").each do |substring|
              must { wildcard( :message, "*#{substring.downcase}*") }
            end
          end   
        
          # Facility
          if !filters[:message_case].blank?
            filters[:facility].split(" ").each do |substring|
              must { wildcard( :facility, "*#{substring.downcase}*") }
            end
          end
          
  #       must { string( "message:#{filters[:message]}", {:default_operator => "AND", :analyzer => "whitespace"}) } unless filters[:message].blank?
  #       must { wildcard(:_facility, "*#{filters[:facility]}*") } unless filters[:facility].blank?

          # Severity
          if !filters[:severity].blank? and filters[:severity_above].blank?
            must { term(:level, filters[:severity]) }
          end

          # Host
          must { term(:host, filters[:host]) } unless filters[:host].blank?

          # Additional fields.
          Quickfilter.extract_additional_fields_from_request(filters).each do |key, value|
            must { term("_#{key}".to_sym, value) }
          end

          # Possibly narrow down to stream?
          unless opts[:stream_id].blank?
            must { term(:streams, opts[:stream_id]) }
          end
          
          # Severity (or higher)
          if !filters[:severity].blank? and !filters[:severity_above].blank?
            must { range(:level, :to => filters[:severity].to_i) }
          end
      
          # Timeframe.
          from = DateTime::parse(filters[:from]).to_time.to_i unless filters[:from].blank?
          to = DateTime::parse(filters[:to]).to_time.to_i unless filters[:to].blank?
          from ||= last_poll_time
          to ||= less_than
                 
          must { range(:created_at, :gt => [from, last_poll_time].max, :lt => [to, less_than].min) }
          
          #if !filters[:date].blank?
          #  range = Quickfilter.get_conditions_timeframe(filters[:date])
          #  must { range(:created_at, :gt => range[:greater], :lt => range[:lower]) }
          #end
          
          unless opts[:hostname].blank?
            must { term(:host, opts[:hostname]) }
          end
          
          # XXX Duplicated?
          # Possibly narrow down to stream?
          unless opts[:stream_id].blank?
            must { term(:streams, opts[:stream_id]) }
          end
          
          # File name
          must { term(:file, filters[:file]) } unless filters[:file].blank?

          # Line number
          must { term(:line, filters[:line]) } unless filters[:line].blank?
        end
      end

    end

    result = wrap(r)
    postprocess(result, {:message => filters[:message], :facility=> filters[:facility], :message_case_sensitive => filters[:message_case], :facility_case_sensitive => filters[:facility_case]})
  end
  
  def self.all_by_quickfilter_since(filters, opts = {}, last_poll_time = Time.now.utc, extra_options = {})
    r = search @default_query_options.merge(extra_options) do
      query do
        boolean do
          
          # Short message  
          if !filters[:message_case].blank?
            filters[:message].split(" ").each do |substring|
              must { wildcard( :message, "*#{substring.downcase}*") }
            end
          end   
        
          # Facility
          if !filters[:message_case].blank?
            filters[:facility].split(" ").each do |substring|
              must { wildcard( :facility, "*#{substring.downcase}*") }
            end
          end
          
  #       must { string( "message:#{filters[:message]}", {:default_operator => "AND", :analyzer => "whitespace"}) } unless filters[:message].blank?
  #       must { wildcard(:_facility, "*#{filters[:facility]}*") } unless filters[:facility].blank?

          # Severity
          if !filters[:severity].blank? and filters[:severity_above].blank?
            must { term(:level, filters[:severity]) }
          end

          # Host
          must { term(:host, filters[:host]) } unless filters[:host].blank?

          # Additional fields.
          Quickfilter.extract_additional_fields_from_request(filters).each do |key, value|
            must { term("_#{key}".to_sym, value) }
          end

          # Possibly narrow down to stream?
          unless opts[:stream_id].blank?
            must { term(:streams, opts[:stream_id]) }
          end
          
          # Severity (or higher)
          if !filters[:severity].blank? and !filters[:severity_above].blank?
            must { range(:level, :to => filters[:severity].to_i) }
          end
      
          # Timeframe.
          from = DateTime::parse(filters[:from]).to_time.to_i unless filters[:from].blank?
          to = DateTime::parse(filters[:to]).to_time.to_i unless filters[:to].blank?
          from ||= last_poll_time
                 
          must { range(:created_at, :gt => [from, last_poll_time].max, :lt => to) }
          
          #if !filters[:date].blank?
          #  range = Quickfilter.get_conditions_timeframe(filters[:date])
          #  must { range(:created_at, :gt => range[:greater], :lt => range[:lower]) }
          #end
          
          unless opts[:hostname].blank?
            must { term(:host, opts[:hostname]) }
          end
          
          # XXX Duplicated?
          # Possibly narrow down to stream?
          unless opts[:stream_id].blank?
            must { term(:streams, opts[:stream_id]) }
          end
          
          # File name
          must { term(:file, filters[:file]) } unless filters[:file].blank?

          # Line number
          must { term(:line, filters[:line]) } unless filters[:line].blank?
        end
      end

    end

    result = wrap(r)
    postprocess(result, {:message => filters[:message], :facility=> filters[:facility], :message_case_sensitive => filters[:message_case], :facility_case_sensitive => filters[:facility_case]})
  end
  
  
  
  
  
  

  def self.total_count
    # search with size 0 instead of count because of this issue: https://github.com/karmi/tire/issues/100
    search("*", :size => 0).total
  end

  def self.stream_count(stream_id)
    # search with size 0 instead of count because of this issue: https://github.com/karmi/tire/issues/100
    search("streams:#{stream_id}", :size => 0).total
  end

  def self.oldest_message
    r = search({ :sort => "created_at asc", :size => 1 }) do
      query { all }
    end.first

    wrap(r)
  end

  def self.all_in_range(page, from, to, opts = {})
    raise "You can only pass stream_id OR hostname" if !opts[:stream_id].blank? and !opts[:hostname].blank?

    options = pagination_options(page).merge(@default_query_options)

    r = search(options) do
      query do
        all

        # Possibly narrow down to stream?
        unless opts[:stream_id].blank?
          term(:streams, opts[:stream_id])
        end
        
        # Possibly narrow down to host?
        unless opts[:hostname].blank?
          term(:host, opts[:hostname])
        end
      end
          
      filter 'range', { :created_at => { :gte => from, :lte => to } }
    end

    wrap(r)
  end

  def self.delete_message(id)
    result = Tire.index(INDEX_NAME).remove(TYPE_NAME, id)
    Tire.index(INDEX_NAME).refresh
    return false if result.nil? or result["ok"] != true

    return true
  end

  # Returns how the text is broken down to terms.
  def self.analyze(text, field = "message")
    result = Tire.index(INDEX_NAME).analyze(text, :field => "message.#{field}")
    return Array.new if result == false
    
    result["tokens"].map { |t| t["token"] }
  end

  def self.message_mapping
    Tire.index(INDEX_NAME).mapping["message"] rescue {}
  end

  def self.mapping_valid?
    mapping = message_mapping

    store_generic = mapping["dynamic_templates"][0]["store_generic"]
    return false if store_generic["mapping"]["index"] != "not_analyzed"
    return false if store_generic["match"] != "*"
   
    properties = mapping["properties"] 
    expected = { "analyzer" => "whitespace", "type" => "string" }
    return false if properties["full_message"] != expected
    return false if properties["message"] != expected

    true
  rescue
    false
  end

  private
  
  def self.postprocess(x, options = {})
    return nil if x.nil?
    
    message_substring = options[:message] || ""
    message_case_sensitive = options[:message_case_sensitive]
    facility_substring = options[:facility] || ""
    facility_case_sensitive = options[:facility_case_sensitive]

    # Remove elements if they dont have our message/facility as substring
    # See http://stackoverflow.com/questions/3260686/how-can-i-use-arraydelete-while-iterating-over-the-array
    x.delete_if do |document|
      skip_message = false
      
      # check message field
      message = document.message
      if !message_substring.empty?
        if message_case_sensitive == "true"
          skip_message = !message.include?(message_substring)
        else
          skip_message = !message.downcase.include?(message_substring.downcase)
        end      
      end
            
      # check facility field
      facility = document.facility
      if !facility_substring.empty? && !skip_message
        if facility_case_sensitive == "true"
          skip_message = !facility.include?(facility_substring)
        else
          skip_message = !facility.downcase.include?(facility_substring.downcase)
        end      
      end
      
      skip_message
    end   
        
    return x
  end

  def self.wrap(x)
    return nil if x.nil?

    case(x)
      when Tire::Results::Item then Message.parse_from_elastic(x)
      when Tire::Results::Collection then wrap_collection(x)
      else
        Rails.logger.error "Unsupported result type while trying to wrap ElasticSearch response: #{x.class}"
        raise UnsupportedResultType
    end
  end

  def self.wrap_collection(c)
    r = MessageResult.new(c.results.map { |i| wrap(i) })
    r.total_result_count = c.total
    return r
  end

  def self.pagination_options(page)
    page = 1 if page.blank?

    { :per_page => Message::LIMIT, :page => page }
  end
  
end
