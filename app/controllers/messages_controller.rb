class MessagesController < ApplicationController
  before_filter :do_scoping

  filter_access_to :all

  @@last_poll_time = { "graylog2" => Time.now.utc }
  @@last_poll_time_for_stream = Hash.new
  @@last_message_created_at = Hash.new
  @@threads = Hash.new   #  { "graylog2" => Thread("graylog2"), ...}
  @@thread_filters = Hash.new
  POLL_INTERVAL = 3   # s
  
  Juggernaut.options= {:port => 3002}
  
  # XXX ELASTIC clean up triple-duplicated quickfilter shit
  def do_scoping
    Juggernaut.publish("scoping1", "1")
    # AJAX requests shouldn't do prequest filtering/data-retrieval
    return if params[:applyFilter] || params[:onlyData] || params[:jumpUp] || params[:login]
    
    if params[:host_id]
      @scoping = :host

      @host = Host.find(:first, :conditions => {:host=> params[:host_id]})
      if params[:filters].blank?
        @messages = MessageGateway.all_of_host_paginated(@host.host, params[:page], 0)
      else
        @additional_filters = Quickfilter.extract_additional_fields_from_request(params[:filters])
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page], :hostname => @host.host)
        @quickfilter_result_count = @messages.total_result_count
      end
      @total_count = @messages.total_result_count
    elsif params[:stream_id]
      @scoping = :stream
      @stream = Stream.find_by_id(params[:stream_id])
      @is_favorited = current_user.favorite_streams.include?(params[:stream_id])

      # Check streams for reader.
      
      if params[:filters].blank?
        @messages = MessageGateway.all_of_stream_paginated(@stream.id, params[:page], 0)
        @total_count = @messages.total_result_count
      else
        @additional_filters = Quickfilter.extract_additional_fields_from_request(params[:filters])
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page], :stream_id => @stream.id)
        @quickfilter_result_count = @messages.total_result_count
        @total_count = MessageGateway.stream_count(@stream.id) # XXX ELASTIC Possibly read cached from first all_paginated result?!
      end
    else
      @scoping = :messages

      if params[:filters].blank?
        @messages = MessageGateway.all_paginated(params[:page], 0)
        Juggernaut.publish("scoping2", "2")
        @total_count = @messages.total_result_count
      else
        @additional_filters = Quickfilter.extract_additional_fields_from_request(params[:filters])
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page])
        Juggernaut.publish("scoping3", "3")
        @quickfilter_result_count = @messages.total_result_count
        @total_count = MessageGateway.total_count # XXX ELASTIC Possibly read cached from first all_paginated result?!
      end
    end
  rescue Tire::Search::SearchRequestFailed
      flash[:error] = "Syntax error in search query or empty index."
      @messages = MessageResult.new
      @total_count = 0
      @quickfilter_result_count = @messages.total_result_count
  end

  public
  def index
    @has_sidebar = true
    @load_flot = true
    @use_backtotop = false
    Juggernaut.publish("index", "1")
    
    ObserversController.start

    if ::Configuration.allow_version_check
      @last_version_check = current_user.last_version_check
    end
    
    if params[:onlyData]      
      if !params[:filters].nil?
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page], {}, 0, {}, session[:time_of_last_request])
        Juggernaut.publish("index", "2.1")
      else
        @messages = MessageGateway.all_paginated(params[:page], 0, session[:time_of_last_request])
        Juggernaut.publish("index", "2.2")
      end
      render :js => @messages.to_json
    end     
      
    if params[:filters] && params[:applyFilter] && params[:login] && !params[:onlyData]
      session[:time_of_last_request] = Time.now.utc.to_i
      MessagesController.applyFilter(params[:login], params[:filters])
      @messages = MessageGateway.all_by_quickfilter(params[:filters], 1, {}, 0) rescue nil
      Juggernaut.publish("index", "2.3")
      render :js => @messages.to_json
    end
    
    
    if params[:jumpUp] && params[:login]  
     
      login = params[:login]
      if params[:jumpUp] == "true"
          Juggernaut.publish("index", params[:latest_timestamp])
          latest_timestamp = DateTime::parse(params[:latest_timestamp]).to_time.utc.to_i unless params[:latest_timestamp] == "0"
          latest_timestamp ||= Time.now.utc.to_i
  
          old_filter = @@thread_filters[login]
          if !old_filter.nil?
            new_filter = Hash[old_filter] # Creates new object
            new_filter.delete(:to)
            new_filter[:from] = old_filter[:to]
            new_filter[:to] = Time.now.utc.to_s
            dummy_messages = MessageGateway.all_by_quickfilter(new_filter, 1, {}, latest_timestamp, { :sort => "created_at asc"})
            Juggernaut.publish("index", "2.4")
            if !dummy_messages.empty?
              new_to = dummy_messages[dummy_messages.size - 1].created_at + 1 # All of this was to get this value
              render :text => new_to
            else
              render :text => Time.now.utc.to_time.to_i
            end
          else
            dummy_messages = MessageGateway.all_paginated(1, latest_timestamp, Time.now.utc.to_i, { :sort => "created_at asc"}) rescue nil
            Juggernaut.publish("index", "2.5")
            if !dummy_messages.empty?
              new_to = dummy_messages[dummy_messages.size - 1].created_at + 1 # All of this was to get this value
              render :text => new_to
            else
              render :text => "0"              
            end            
          end
      else
        # This clears the client's message table, so reset the timestamp pointer
        session[:time_of_last_request] = Time.now.utc.to_i
        
        if !@@thread_filters[login].nil? 
          Juggernaut.publish("index", "3.1")
          result = MessageGateway.all_by_quickfilter(@@thread_filters[login].merge({:to => Time.at(params[:to].to_i).utc.to_s}), params[:page], {}, 0, {}, session[:time_of_last_request])
          render :js => result.to_json
        else
          Juggernaut.publish("index", "3.2")
          result = MessageGateway.all_paginated(params[:page], 0, Time.at(params[:to].to_i).utc.to_i) rescue nil
          render :js => result.to_json
        end         
      end
    end
    
      
    #if params[:login]
      #MessagesController.applyFilter(params[:login], params[:filters])    
      #render :js => "true"
    #end    
    

  end

  def show
    @has_sidebar = true
    @load_flot = true
    
    @message = MessageGateway.retrieve_by_id(params[:id])
    @terms = MessageGateway.analyze(@message.message)
    @comments = Messagecomment.all_matched(@message)
        
    if params[:partial]
      render :partial => "full_message"
      return
    end
  end

  def destroy
    render :status => :forbidden, :text => "forbidden" and return if !::Configuration.allow_deleting

    if MessageGateway.delete_message(params[:id])
      flash[:notice] = "Message has been deleted."
    else
      flash[:error] = "Could not delete message."
    end

    redirect_to :action => "index"
  end

  def showrange
    @has_sidebar = true
    @load_flot = true
    @use_backtotop = false
    
    @from = Time.at(params[:from].to_i-Time.now.utc_offset)
    @to = Time.at(params[:to].to_i-Time.now.utc_offset)

    @messages = MessageGateway.all_in_range(params[:page], @from.to_i, @to.to_i)
    @total_count = @messages.total_result_count
  end

  def getcompletemessage
    message = Message.find params[:id]
    render :text => CGI.escapeHTML(message.message)
  end
  
  def self.start(login="graylog2")
    if @@threads[login].nil?
      @@last_message_created_at[login] = Time.now.utc.to_i
      
      @@threads[login] = Thread.new(login) do
        until false do     
          
          # Do not use pagination since we are polling
          if !@@thread_filters[login].nil?   
            result = MessageGateway.all_by_quickfilter_since(MessagesController.getFilter(login), {}, @@last_message_created_at[login]) rescue nil
          else
            result = MessageGateway.all_since(@@last_message_created_at[login]) rescue nil
          end
          
          if !result.empty?        
            @@last_message_created_at[login] = result[0].created_at         
            Juggernaut.publish(login, result.to_json) 
          end
          
          sleep MessagesController::POLL_INTERVAL
        end        
      end
    end    
  end
  
  def self.applyFilter(login, filter)
    @@thread_filters[login] = filter
  end
  
  def self.getFilter(login)
    @@thread_filters[login]
  end
  
  def self.clearFilter(login="graylog2")
    @@thread_filters.delete login
  end
  
  def self.stop(login)
    if login.nil?
      @@threads.each do |login_name, thread|
        thread && thread.exit
      end
    else
      @@threads[login] && @@threads[login].exit
      @@threads[login] = nil      
    end    
  end
  

end
