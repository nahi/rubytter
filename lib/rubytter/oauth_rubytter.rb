# -*- coding: utf-8 -*-

class OAuthRubytter < Rubytter

  OAUTH_SITE = 'http://api.twitter.com/'
  OAUTH_SIGNATURE_METHOD = 'HMAC-SHA1'

  # Twitter API client which utilizes OAuth for authorization.
  #
  # access_token: must be instance of OAuth::AccessToken
  #   or
  # {
  #   :token => token,
  #   :secret => secret,
  #   :consumer => { :key => consumer_key, :secret => consumer_secret }
  # }
  #   or
  # {
  #   :user_name => 'user_name',
  #   :password => 'password',
  #   :consumer => { :key => consumer_key, :secret => consumer_secret }
  # } for xAuth.
  #
  # options hash:
  #   :host => host string. follows OAUTH_SITE by default.
  #   :enable_ssl => true/false. false by default.
  #
  def initialize(config = {}, options = {})
    options = set_default_option(options, :host, URI.parse(OAUTH_SITE).host)
    options = set_default_option(options, :enable_ssl, false)
    super(config, options)
    consumer = get_attr(config, :consumer)
    consumer_key = get_attr(consumer, :key)
    consumer_secret = get_attr(consumer, :secret)
    token = get_attr(config, :token)
    secret = get_attr(config, :secret)
    user_name = get_attr(config, :user_name) # for xAuth
    password = get_attr(config, :password) # for xAuth

    # xAuth support
    if token.nil? and secret.nil? and user_name and password
      ac = OAuth.new(consumer_key, consumer_secret).get_access_token_with_xauth(user_name, password)
      token, secret = ac.token, ac.secret
    end

    # configure
    config = HTTPClient::OAuth::Config.new
    config.consumer_key = consumer_key
    config.consumer_secret = consumer_secret
    config.token = token
    config.secret = secret
    config.signature_method = OAUTH_SIGNATURE_METHOD
    config.http_method = :get

    site = OAUTH_SITE
    site.sub!(/\Ahttp/, 'https') if options[:enable_ssl]
    @connection.client.www_auth.oauth.set_config(site, config)
    @connection.client.www_auth.oauth.challenge(site)
  end

  def verify_credentials
    # nothing to do more for OAuth.
  end

private

  def get_attr(obj, key)
    if obj.respond_to?(key)
      obj.send(key)
    elsif obj.respond_to?(:[])
      obj[key]
    else
      nil
    end
  end

  def set_default_option(options, key, value)
    if options.key?(key)
      options
    else
      options.merge(key => value)
    end
  end
end
