# -*- coding: utf-8 -*-
require 'httpclient'

class Rubytter
  class Connection
    attr_reader :client
    attr_reader :uri

    def initialize(options = {})
      @uri = setup_uri(options).freeze
      if @uri.scheme == 'https'
        @non_ssl_uri = new_uri_scheme(@uri, 'http')
        @non_ssl_uri.freeze
      else
        @non_ssl_uri = @uri
      end
      @client = setup_client(options)
    end

    def request(method, path, query, body, extheader, opt = {})
      path = '/' + path unless path[0] == ?/
      uri = create_uri(path, opt)
      @client.request(method, uri, query, body, extheader)
    end
    
  private

    def create_uri(path, options)
      uri = options[:non_ssl] ? @non_ssl_uri : @uri
      uri = uri.dup
      uri.path = path
      uri.host = options[:host] if options[:host]
      uri
    end

    def setup_uri(options)
      uri = new_uri
      uri.host = options[:host] || 'twitter.com'
      if options[:enable_ssl]
        uri = new_uri_scheme(uri, 'https')
      end
      uri
    end

    def setup_client(options)
      client = HTTPClient.new
      client.agent_name = options[:agent_name] if options[:agent_name]
      client.proxy = build_proxy_uri(options)
      if options[:login] and options[:password]
        uri = @uri.dup
        client.set_auth(uri, options[:login], options[:password])
        # uglish but we want to restrict domain to twitter.com and api.twitter.com
        uri.host = 'api.twitter.com'
        client.set_auth(uri, options[:login], options[:password])
      end
      client.debug_dev = Logger.new(options[:wiredump]) if options[:wiredump]
      client
    end

    def build_proxy_uri(options)
      if options[:proxy_host] and options[:proxy_port]
        proty_uri = new_uri
        proxy_uri.host = options[:proxy_host]
        proxy_uri.port = options[:proxy_port]
        if options[:proxy_user_name]
          proxy_uri.user = options[:proxy_user_name]
          if options[:proxy_password]
            proxy_uri.password = options[:proxy_password]
          end
        end
        proxy_uri
      elsif options[:proxy]
        options[:proxy]
      end
    end

    def new_uri
      URI.parse('http://dummy/')
    end

    def new_uri_scheme(uri, scheme)
      uri = uri.dup
      uri.scheme = scheme
      URI.parse(uri.to_s)
    end
  end
end
