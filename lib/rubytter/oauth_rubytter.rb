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
  #
  # options hash:
  #   :host => host string. follows OAUTH_SITE by default.
  #   :enable_ssl => true/false. false by default.
  #
  def initialize(config = {}, options = {})
    options = set_default_option(options, :host, URI.parse(OAUTH_SITE).host)
    options = set_default_option(options, :enable_ssl, false)
    super(config, options)
    token = get_attr(config, :token)
    secret = get_attr(config, :secret)
    consumer = get_attr(config, :consumer)
    consumer_key = get_attr(consumer, :key)
    consumer_secret = get_attr(consumer, :secret)

    # configure
    config = HTTPClient::OAuth::Config.new
    config.consumer_key = consumer_key
    config.consumer_secret = consumer_secret
    config.token = token
    config.secret = secret
    config.signature_method = OAUTH_SIGNATURE_METHOD
    config.http_method = :get

    @connection.client.www_auth.oauth.set_config(OAUTH_SITE, config)
    @connection.client.www_auth.oauth.challenge(OAUTH_SITE)
  end

private

  def get_attr(obj, key)
    if obj.respond_to?(key)
      obj.send(key)
    elsif obj.respond_to?(:[])
      obj[key]
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
