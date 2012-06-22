require 'digest/sha1'

class User
  include Mongoid::Document
  include Authentication
  include Authentication::ByPassword
  include Authentication::ByCookieToken

  validates_presence_of     :login
  validates_length_of       :login,    :within => 3..40
  validates_format_of       :login,    :with => Authentication.login_regex, :message => Authentication.bad_login_message

  STANDARD_ROLE = :admin

  # HACK HACK HACK -- how to do attr_accessible from here?
  # prevents a user from submitting a crafted form that bypasses activation
  # anything else you want your user to change should be added here.
  attr_accessible :login, :role

  field :login, :type => String
  field :role, :type => String
  field :salt, :type => String
  field :remember_token, :type => String
  field :remember_token_expires_at
  field :last_version_check, :type => Integer

  index :login,          :background => true, :unique => true
  index :remember_token, :background => true, :unique => true

  # Authenticates a user by their login name.  Returns the user or nil.
  #
  # uff.  this is really an authorization, not authentication routine.
  # We really need a Dispatch Chain here or something.
  # This will also let us return a human error message.
  #
  def self.authenticate(login)
    return nil if login.blank?
    find_by_login(login.downcase) # need to get the salt
  end

  def self.find_by_id(_id)
    find(:first, :conditions => {:_id => BSON::ObjectId(_id)})
  end

  def self.find_by_remember_token(token)
    find(:first, :conditions => {:remember_token => token})
  end

  def self.find_by_login(login)
    find(:first, :conditions => {:login => login})
  end

  def login=(value)
    write_attribute :login, (value ? value.downcase : nil)
  end

  def display_name
    self.login
  end

  def reader?
    false
  end

  def roles
    role_symbols
  end

  def role_symbols
    [(role.blank? ? STANDARD_ROLE : role.to_sym)]
  end

  def valid_roles
    [:admin]
  end
end
