class MessagesController < ApplicationController
  before_filter :do_scoping

  filter_access_to :all

  @@last_poll_time = { "graylog2" => Time.now.utc }
  @@last_poll_time_for_stream = Hash.new
  @@last_message_created_at = Hash.new
  @@threads = Hash.new   #  { "graylog2" => Thread("graylog2"), ...}
  @@thread_filters = Hash.new
  POLL_INTERVAL = 1   # s
  
  Juggernaut.options= {:port => 3002}
  
  
  # XXX ELASTIC clean up triple-duplicated quickfilter shit
  def do_scoping
    if params[:host_id]
      @scoping = :host
      block_access_for_non_admins

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
      block_access_for_non_admins if !@stream.accessable_for_user?(current_user)
      
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
      unless (params[:action] == "show")
        block_access_for_non_admins
      end

      if params[:filters].blank?
        @messages = MessageGateway.all_paginated(params[:page], 0)
        @total_count = @messages.total_result_count
      else
        @additional_filters = Quickfilter.extract_additional_fields_from_request(params[:filters])
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page])
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

  # Not possible to do this via before_filter because of scope decision by params hash
  def block_access_for_non_admins
    if current_user.role != "admin"
      flash[:error] = "You have no access rights for this section."
      redirect_to :controller => "streams", :action => "index"
    end
  end

  public
  def index
    @has_sidebar = true
    @load_flot = true
    @use_backtotop = false

    if ::Configuration.allow_version_check
      @last_version_check = current_user.last_version_check
    end
    
    if params[:onlyData]
      if params[:filters]
        @messages = MessageGateway.all_by_quickfilter(params[:filters], params[:page])
      else
        @messages = MessageGateway.all_paginated(params[:page])
      end
      render :js => @messages.to_json
    end     
      
    if params[:filters] && params[:applyFilter] && params[:login] && !params[:onlyData]
      MessagesController.applyFilter(params[:login], params[:filters])
      @messages = MessageGateway.all_by_quickfilter(params[:filters], 1, {}, 0) rescue nil
      render :js => @messages.to_json
    end
    
    
    if params[:jumpUp] && params[:login]   
      #Juggernaut.publish("1.0", params[:login])
      #Juggernaut.publish("1.0", params[:jumpUp])
      login = params[:login]
      if params[:jumpUp] == "true"
          #Juggernaut.publish("1.1", params[:jumpUp])
          old_filter = @@thread_filters[login]
          if !old_filter.nil?
            new_filter = Hash[old_filter] # Creates new object
            new_filter.delete(:to)
            new_filter[:from] = old_filter[:to]
            new_filter[:to] = Time.now.utc.to_s
            dummy_messages = MessageGateway.all_by_quickfilter(new_filter, 1, {}, 0, { :sort => "created_at asc"})
            if !dummy_messages.empty?
              new_to = dummy_messages[dummy_messages.size - 1].created_at + 1 # All of this was to get this value
              render :text => new_to
            else
              render :text => Time.now.utc.to_time.to_i
            end
          else
              render :text => "0"
          end
      else
        #Juggernaut.publish("1.2", params[:jumpUp])
        if !@@thread_filters[login].nil? 
          #Juggernaut.publish("1.3", @@thread_filters[login].merge({:to => Time.at(params[:to].to_i).utc.to_s}))
          result = MessageGateway.all_by_quickfilter(@@thread_filters[login].merge({:to => Time.at(params[:to].to_i).utc.to_s}), params[:page], {}, 0)
          render :js => result.to_json
        else
          result = MessageGateway.all_paginated(params[:page], 0) rescue nil
          render :js => result.to_json
        end         
      end
    end
    
      
    #if params[:login]
      #MessagesController.applyFilter(params[:login], params[:filters])       
    #Juggernaut.publish("graylog2", current_user.login) 
    MessagesController.start(current_user.login)
      #render :js => "true"
    #end    
    

  end

  def show
    @has_sidebar = true
    @load_flot = true
    
    @message = MessageGateway.retrieve_by_id(params[:id])
    @terms = MessageGateway.analyze(@message.message)

    unless @message.accessable_for_user?(current_user)
      block_access_for_non_admins
    end

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
          if !@@thread_filters[login].nil?   
            result = MessageGateway.all_by_quickfilter(@@thread_filters[login], 1, {}, @@last_message_created_at[login]) rescue nil
          else
            result = MessageGateway.all_paginated(1, @@last_message_created_at[login]) rescue nil
          end
          if !result.empty?          
            @@last_message_created_at[login] = result[0].created_at            
            #Juggernaut.publish(login, result.to_json) 
          end
          sleep MessagesController::POLL_INTERVAL
        end        
      end
    end    
  end
  
  def self.applyFilter(login, filter)
    @@thread_filters[login] = filter
  end
  
  def self.clearFilter(login="graylog2")
    @@thread_filters.delete login
  end
  
  def self.end(login)
    if login.nil?
      @@threads.each do |login_name, thread|
        thread.stop
      end
    else
      @@threads[login].stop
    end    
  end
  

end
