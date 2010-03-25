require 'oauthclient'

class Rubytter

  # class for getting request_token and access_token.
  class OAuth

    REQUEST_TOKEN_URL = 'https://api.twitter.com/oauth/request_token'
    ACCESS_TOKEN_URL = 'https://twitter.com/oauth/access_token'
    OAUTH_SIGNATURE_METHOD = 'HMAC-SHA1'

    # emulates AccessToken in OAuth gem.
    class Token
      attr_reader :params

      def initialize(params)
        @params = params || {}
      end

      def token
        @params['oauth_token']
      end

      def secret
        @params['oauth_token_secret']
      end
    end

    attr_reader :consumer

    def initialize(key, secret, opt = {})
      unless opt.is_a?(Hash)
        opt = {:ca_file => opt}
      end
      @key = key
      @secret = secret
      @consumer = create_consumer(opt)
    end

    def get_request_token
      res = consumer.get_request_token(REQUEST_TOKEN_URL)
      Token.new(res.oauth_params)
    end

    def get_access_token(token, secret, verifier)
      res = consumer.get_access_token(ACCESS_TOKEN_URL, token, secret, verifier)
      Token.new(res.oauth_params)
    end

    def get_access_token_with_xauth(login, password)
      config = consumer.oauth_config
      config.token = ''
      config.secret = ''
      xauth_params = {
        :x_auth_mode => "client_auth",
        :x_auth_username => login,
        :x_auth_password => password
      }
      res = consumer.get(ACCESS_TOKEN_URL, xauth_params)
      params = get_oauth_response(res)
      Token.new(params)
    end

  private

    def create_consumer(opt)
      consumer = OAuthClient.new
      config = consumer.oauth_config
      config.consumer_key = @key
      config.consumer_secret = @secret
      config.signature_method = OAUTH_SIGNATURE_METHOD
      config.http_method = :get
      if opt[:ca_file]
        consumer.ssl_config.set_trust_ca(opt[:ca_file])
      end
      consumer
    end

    # TODO: HTTPClient should publish this function.
    def get_oauth_response(res)
      body = res.content
      body.split('&').inject({}) { |r, e|
        key, value = e.split('=', 2)
        r[unescape(key)] = unescape(value)
        r
      }
    end

    def unescape(escaped)
      escaped ? ::HTTPClient::HTTP::Message.unescape(escaped) : nil
    end
  end
end
