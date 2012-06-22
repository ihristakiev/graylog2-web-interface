class ObserversController < ApplicationController
  
  def self.start
    thread = Thread.new("test") do
        Juggernaut.subscribe do |event, data|   # this is a blocking call, should never be used in normal controller code
          case event
            when :subscribe
              if !data.nil?
                MessagesController.start data["channel"]
              end
            when :unsubscribe
                MessagesController.stop data["channel"]
          end
        end
    end  
  end
  
end