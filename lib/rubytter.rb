# -*- coding: utf-8 -*-
require 'json'
require 'httpclient'
require 'cgi' # for unescapeHTML
require 'rubytter/core_ext'
require 'rubytter/connection'
begin
  require 'rubytter/oauth'
  require 'rubytter/oauth_rubytter'
rescue LoadError
end

class Rubytter
  VERSION = File.read(File.join(File.dirname(__FILE__), '../VERSION')).strip

  class APIError < StandardError
    attr_reader :response
    def initialize(msg, response = nil)
      super(msg)
      @response = response
    end
  end

  module ResponseHeaderExtension
    attr_accessor :headers
    attr_accessor :ratelimit_class
    attr_accessor :ratelimit_limit
    attr_accessor :ratelimit_remaining
    attr_accessor :ratelimit_reset
    attr_accessor :transaction
    attr_accessor :runtime
    attr_accessor :revision
  end

  attr_reader :user_name
  alias login user_name
  attr_accessor :host, :header
  attr_reader :connection

  # Former API: initialize(login = nil, password = nil, options = {})
  # Prefer API: initialize(config = {}, options = {})
  def initialize(config = nil, password_or_options = nil, options = {})
    if config.is_a?(Hash)
      options = password_or_options || {}
    else
      config = {
        :user_name => config,
        :password => password_or_options
      }
    end
    @user_name = config[:user_name]
    @host = 'api.twitter.com'
    @header = {}
    setup(options.merge(:user_name => @user_name, :password => config[:password]))
  end

  def setup(options)
    options = options.dup
    @user_name = options[:user_name] if options[:user_name]
    @host = options[:host] if options[:host]
    @header.merge!(options[:header]) if options[:header]
    @app_name = options[:app_name]
    options[:agent_name] ||= "Rubytter/#{VERSION} (http://github.com/jugyo/rubytter)"
    options[:enable_ssl] = true unless options.key?(:enable_ssl)
    @connection = Connection.new(options)
  end

  def self.api_settings
    # method name             path for API                    http method
    "
      update_status           /1/statuses/update                post
      remove_status           /1/statuses/destroy/%s            delete
      public_timeline         /1/statuses/public_timeline
      home_timeline           /1/statuses/home_timeline
      friends_timeline        /1/statuses/friends_timeline
      replies                 /1/statuses/replies
      mentions                /1/statuses/mentions
      user_timeline           /1/statuses/user_timeline/%s
      show                    /1/statuses/show/%s
      friends                 /1/statuses/friends/%s
      followers               /1/statuses/followers/%s
      retweet                 /1/statuses/retweet/%s            post
      retweets                /1/statuses/retweets/%s
      retweeted_by_me         /1/statuses/retweeted_by_me
      retweeted_to_me         /1/statuses/retweeted_to_me
      retweets_of_me          /1/statuses/retweets_of_me
      user                    /1/users/show/%s
      direct_messages         /1/direct_messages
      sent_direct_messages    /1/direct_messages/sent
      send_direct_message     /1/direct_messages/new            post
      remove_direct_message   /1/direct_messages/destroy/%s     delete
      follow                  /1/friendships/create/%s          post
      leave                   /1/friendships/destroy/%s         delete
      friendship_exists       /1/friendships/exists
      followers_ids           /1/followers/ids/%s
      friends_ids             /1/friends/ids/%s
      favorites               /1/favorites/%s
      favorite                /1/favorites/create/%s            post
      remove_favorite         /1/favorites/destroy/%s           delete
      verify_credentials      /1/account/verify_credentials     get
      end_session             /1/account/end_session            post
      update_delivery_device  /1/account/update_delivery_device post
      update_profile_colors   /1/account/update_profile_colors  post
      limit_status            /1/account/rate_limit_status
      update_profile          /1/account/update_profile         post
      enable_notification     /1/notifications/follow/%s        post
      disable_notification    /1/notifications/leave/%s         post
      block                   /1/blocks/create/%s               post
      unblock                 /1/blocks/destroy/%s              delete
      block_exists            /1/blocks/exists/%s               get
      blocking                /1/blocks/blocking                get
      blocking_ids            /1/blocks/blocking/ids            get
      saved_searches          /1/saved_searches                 get
      saved_search            /1/saved_searches/show/%s         get
      create_saved_search     /1/saved_searches/create          post
      remove_saved_search     /1/saved_searches/destroy/%s      delete
      create_list             /1/:user/lists                    post
      update_list             /1/:user/lists/%s                 put
      delete_list             /1/:user/lists/%s                 delete
      lists                   /1/%s/lists
      lists_followers         /1/%s/lists/memberships
      list_statuses           /1/%s/lists/%s/statuses
      list                    /1/%s/lists/%s
      list_members            /1/%s/%s/members
      add_member_to_list      /1/:user/%s/members               post
      remove_member_from_list /1/:user/%s/members               delete
      list_following          /1/%s/%s/subscribers
      follow_list             /1/%s/%s/subscribers              post
      remove_list             /1/%s/%s/subscribers              delete
    ".strip.split("\n").map{|line| line.strip.split(/\s+/)}
  end

  api_settings.each do |array|
    method, path, http_method = *array
    http_method ||= 'get'
    if /%s/ =~ path
      eval <<-EOS
        def #{method}(*args)
          path = user_name ? '#{path}'.gsub(':user', user_name) :'#{path}'
          params = args.last.kind_of?(Hash) ? args.pop : {}
          path = path % args
          path.sub!(/\\/\\z/, '')
          #{http_method}(path, params)
        end
      EOS
    else
      eval <<-EOS
        def #{method}(params = {})
          path = user_name ? '#{path}'.gsub(':user', user_name) :'#{path}'
          #{http_method}(path, params)
        end
      EOS
    end
  end

  alias_method :__create_list, :create_list
  def create_list(name, params = {})
    __create_list(params.merge({:name => name}))
  end

  alias_method :__add_member_to_list, :add_member_to_list
  def add_member_to_list(list_slug, user_id, params = {})
    __add_member_to_list(list_slug, params.merge({:id => user_id}))
  end

  alias_method :__remove_member_from_list, :remove_member_from_list
  def remove_member_from_list(list_slug, user_id, params = {})
    __remove_member_from_list(list_slug, params.merge({:id => user_id}))
  end

  alias_method :__update_status, :update_status
  def update_status(params = {})
    params[:source] = @app_name if @app_name
    __update_status(params)
  end

  alias_method :__create_saved_search, :create_saved_search
  def create_saved_search(arg)
    arg = {:query => arg} if arg.kind_of?(String)
    __create_saved_search(arg)
  end

  def update(status, params = {})
    update_status(params.merge({:status => status}))
  end

  def direct_message(user, text, params = {})
    send_direct_message(params.merge({:user => user, :text => text}))
  end

  def get(path, params = {})
    path += '.json'
    res = @connection.get(path, params, @header)
    parse_response(res)
  end

  def post(path, params = {})
    path += '.json'
    res = @connection.post(path, params, @header)
    parse_response(res)
  end

  # ignore params. DELETE with params?
  def delete(path, params = {})
    path += '.json'
    res = @connection.delete(path, @header)
    parse_response(res)
  end

  def search(query, params = {})
    path = '/search.json'
    params = params.merge(:q => query)
    res = @connection.get(path, params, @header, :host => "search.twitter.com", :non_ssl => true)
    json_data = response_to_json(res)
    if json_data['results']
      with_header_ext(res) {
        Rubytter.structize(json_data['results'].map { |result| search_result_to_hash(result) })
      }
    end
  end

  def search_user(query, params = {})
    path = '/1/users/search.json'
    params = params.merge(:q => query)
    res = @connection.get(path, params, @header, :host => "api.twitter.com")
    @connection.client.debug_dev = nil
    parse_response(res)
  end

  def search_result_to_hash(json)
    # you should not use to_user_id and from_user_id for other than search API.
    # see the warning at Twitter API doc.
    {
      'id' => json['id'],
      'text' => json['text'],
      'source' => json['source'],
      'created_at' => json['created_at'],
      'in_reply_to_user_id' => json['to_user_id'],
      'in_reply_to_screen_name' => json['to_user'],
      'in_reply_to_status_id' => nil,
      'user' => {
        'id' => json['from_user_id'],
        'name' => nil,
        'screen_name' => json['from_user'],
        'profile_image_url' => json['profile_image_url']
      }
    }
  end

  def parse_response(res)
    with_header_ext(res) {
      Rubytter.structize(response_to_json(res))
    }
  end

  def with_header_ext(res)
    obj = yield(res)
    obj.extend(ResponseHeaderExtension)
    obj.headers = res.header.all.find_all { |k, v| /\AX-/i =~ k }
    obj.headers.each do |k, v|
      msg = k.downcase.sub(/\Ax-/, '').tr('-', '_') + '='
      obj.send(msg, v) if obj.respond_to?(msg)
    end
    obj
  end

  def response_to_json(res)
    json_data = JSON.parse(res.content)
    case res.status.to_i
    when 200
      json_data
    else
      raise APIError.new(json_data['error'], res)
    end
  end

  def self.structize(data)
    case data
    when Array
      data.map{|i| structize(i)}
    when Hash
      class << data
        def id
          self[:id]
        end

        def method_missing(name, *args)
          self[name]
        end
      end

      data.keys.each do |k|
        case k
        when String, Symbol # String しかまず来ないだろうからこの判定はいらない気もするなぁ
          data[k] = structize(data[k])
        else
          data.delete(k)
        end
      end

      data.symbolize_keys!
    when String
      CGI.unescapeHTML(data) # ここで unescapeHTML すべきか悩むところではある
    else
      data
    end
  end
end
