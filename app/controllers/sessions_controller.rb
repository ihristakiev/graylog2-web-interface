class SessionsController < ApplicationController

  skip_before_filter :login_required, :except => :destroy

  layout "login"

  def show
    render :action => :new
  end

  def new
    
  end

  def create
    logout_keeping_session!
    user = User.authenticate(params[:login])
    if user
      # Protects against session fixation attacks, causes request forgery
      # protection if user resubmits an earlier form using back
      # button. Uncomment if you understand the tradeoffs.
      # reset_session
      self.current_user = user
      new_cookie_flag = (params[:remember_me] == "1")
      handle_remember_cookie!(new_cookie_flag)
      redirect_to root_path
      flash[:notice] = "Logged in successfully"
    else      
      @user = User.new({ :login => params[:login], :role => "admin"})
      success = @user && @user.save
      if success && @user.errors.empty?
        self.current_user = @user
        new_cookie_flag = (params[:remember_me] == "1")
        handle_remember_cookie!(new_cookie_flag)
        redirect_to root_path
        flash[:notice] = "User has been created."
      else
        note_failed_signin
        @login       = params[:login]
        @remember_me = params[:remember_me]
        render :action => 'new'
      end
    end
  end

  def destroy
    logout_killing_session!
    flash[:notice] = "You have been logged out."
    redirect_back_or_default(root_path)
  end

protected
  # Track failed login attempts
  def note_failed_signin
    flash[:error] = "Couldn't log you in as '#{params[:login]}'"
    Rails.logger.warn "Failed login for '#{params[:login]}' from #{request.remote_ip} at #{Time.now.utc}"
  end
end
