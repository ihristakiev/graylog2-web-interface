class DashboardController < ApplicationController
  filter_resource_access
  #layout "dashboard"

  STANDARD_MAX_MESSAGES = 100
  STANDARD_TIMESPAN = 2  
  @poll_interval = 1
  
  @last_poll_time = { "graylog2" => Time.now.utc }
  @last_poll_time_for_stream = Hash.new
  @last_message_created_at = Hash.new
  @threads = Hash.new   #  { "graylog2" => Thread("graylog2"), ...}
  @thread_filters = Hash.new
  
  def index
    DashboardController.start current_user.login
    if params[:login] && (params[:applyFilter] == true)
      applyFilter(params[:login], params[:filters])
      render :text => "true"
    end    
    
    if params[:stream_id].blank?
      @timespan = Setting.get_message_count_interval(current_user)
      @message_count = MessageCount.total_count_of_last_minutes(@timespan)
      @max_messages = Setting.get_message_max_count(current_user)
      @messages = MessageGateway.all_paginated(1, @last_poll_time)
      @last_poll_time_for_stream ||= Hash.new
      @last_poll_time_for_stream[current_user.login] = Time.now.utc.to_i unless current_user.nil?
    else
      stream = Stream.find_by_id(params[:stream_id])
      @stream_title = stream.title
      if stream.alarm_active and !stream.alarm_limit.blank? and !stream.alarm_timespan.blank?
        @message_count = stream.message_count_since(stream.alarm_timespan.minutes.ago.to_i)
        @timespan = stream.alarm_timespan
        @max_messages = stream.alarm_limit
      else
        @message_count = stream.message_count_since(STANDARD_TIMESPAN.minutes.ago)
        @max_messages = STANDARD_MAX_MESSAGES
        @timespan = STANDARD_TIMESPAN
      end
      @messages = MessageGateway.all_of_stream_paginated(stream.id, 1, last_poll_time_for_stream[stream.id])
      @last_poll_time_for_stream[stream.id] = Time.now.utc.to_i
    end
  end
  
  def self.start(login="graylog2")
    if @threads[login].nil?
      @last_message_created_at[login] = Time.now.utc.to_i - 20   # last 20s of data
      @threads[login] = Thread.new("graylog2") do
        loop do         
          result = MessageGateway.all_paginated(@thread_filters[login], 1, {}, @last_message_created_at[login]) rescue nil
          Juggernaut.publish("graylog2", result.to_json) 
          if !result.empty?       
            @last_message_created_at[login] = result[0].created_at
            Juggernaut.publish("graylog2", result.to_json) 
          end
          sleep(@poll_interval)
        end        
      end
      Juggernaut.publish("graylog2", @threads[login].status) 
      Juggernaut.publish("graylog2", @thread_filters[login]) 
    end    
  end
  
  def self.applyFilter(login, filter)
    @thread_filters[login] = filter
  end
  
  def self.clearFilter(login="graylog2")
    @thread_filters.delete login
  end
  
  def self.end(login)
    if login.nil?
      @threads.each do |login_name, thread|
        thread.stop
      end
    else
      @threads[login].stop
    end    
  end
  
  def self.messages
    @messages
  end


end
