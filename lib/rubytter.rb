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

  attr_reader :login
  attr_accessor :host, :header
  attr_reader :connection

  # Former API: initialize(login = nil, password = nil, options = {})
  # Prefer API: initialize(config = {}, options = {})
  def initialize(login = nil, password_or_options = nil, options = {})
    if login.is_a?(Hash)
      config = login
      options = password_or_options || {}
    else
      config = {
        :user_name => login,
        :password => password_or_options
      }
    end
    @login = config[:user_name]
    @host = 'api.twitter.com'
    @header = {}
    setup(options.merge(:login => @login, :password => config[:password]))
  end

  def setup(options)
    options = options.dup
    @login = options[:login] if options[:login]
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
      update_status           /statuses/update                post
      remove_status           /statuses/destroy/%s            delete
      public_timeline         /statuses/public_timeline
      home_timeline           /statuses/home_timeline
      friends_timeline        /statuses/friends_timeline
      replies                 /statuses/replies
      mentions                /statuses/mentions
      user_timeline           /statuses/user_timeline/%s
      show                    /statuses/show/%s
      friends                 /statuses/friends/%s
      followers               /statuses/followers/%s
      retweet                 /statuses/retweet/%s            post
      retweets                /statuses/retweets/%s
      retweeted_by_me         /statuses/retweeted_by_me
      retweeted_to_me         /statuses/retweeted_to_me
      retweets_of_me          /statuses/retweets_of_me
      user                    /users/show/%s
      direct_messages         /direct_messages
      sent_direct_messages    /direct_messages/sent
      send_direct_message     /direct_messages/new            post
      remove_direct_message   /direct_messages/destroy/%s     delete
      follow                  /friendships/create/%s          post
      leave                   /friendships/destroy/%s         delete
      friendship_exists       /friendships/exists
      followers_ids           /followers/ids/%s
      friends_ids             /friends/ids/%s
      favorites               /favorites/%s
      favorite                /favorites/create/%s            post
      remove_favorite         /favorites/destroy/%s           delete
      verify_credentials      /account/verify_credentials     get
      end_session             /account/end_session            post
      update_delivery_device  /account/update_delivery_device post
      update_profile_colors   /account/update_profile_colors  post
      limit_status            /account/rate_limit_status
      update_profile          /account/update_profile         post
      enable_notification     /notifications/follow/%s        post
      disable_notification    /notifications/leave/%s         post
      block                   /blocks/create/%s               post
      unblock                 /blocks/destroy/%s              delete
      block_exists            /blocks/exists/%s               get
      blocking                /blocks/blocking                get
      blocking_ids            /blocks/blocking/ids            get
      saved_searches          /saved_searches                 get
      saved_search            /saved_searches/show/%s         get
      create_saved_search     /saved_searches/create          post
      remove_saved_search     /saved_searches/destroy/%s      delete
      create_list             /:user/lists                    post
      update_list             /:user/lists/%s                 put
      delete_list             /:user/lists/%s                 delete
      lists                   /%s/lists
      lists_followers         /%s/lists/memberships
      list_statuses           /%s/lists/%s/statuses
      list                    /%s/lists/%s
      list_members            /%s/%s/members
      add_member_to_list      /:user/%s/members               post
      remove_member_from_list /:user/%s/members               delete
      list_following          /%s/%s/subscribers
      follow_list             /%s/%s/subscribers              post
      remove_list             /%s/%s/subscribers              delete
    ".strip.split("\n").map{|line| line.strip.split(/\s+/)}
  end

  api_settings.each do |array|
    method, path, http_method = *array
    http_method ||= 'get'
    if /%s/ =~ path
      eval <<-EOS
        def #{method}(*args)
          path = login ? '#{path}'.gsub(':user', login) :'#{path}'
          params = args.last.kind_of?(Hash) ? args.pop : {}
          path = path % args
          path.sub!(/\\/\\z/, '')
          #{http_method}(path, params)
        end
      EOS
    else
      eval <<-EOS
        def #{method}(params = {})
          path = login ? '#{path}'.gsub(':user', login) :'#{path}'
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
    structize(parse_response(res))
  end

  def post(path, params = {})
    path += '.json'
    res = @connection.post(path, params, @header)
    structize(parse_response(res))
  end

  # ignore params. DELETE with params?
  def delete(path, params = {})
    path += '.json'
    res = @connection.delete(path, @header)
    structize(parse_response(res))
  end

  def search(query, params = {})
    path = '/search.json'
    params = params.merge(:q => query)
    res = @connection.get(path, params, @header, :host => "search.twitter.com", :non_ssl => true)
    json_data = parse_response(res)
    return {} unless json_data['results']
    structize(json_data['results'].map { |result| search_result_to_hash(result) })
  end

  def search_user(query, params = {})
    path = '/1/users/search.json'
    params = params.merge(:q => query)
    res = @connection.get(path, params, @header, :host => "api.twitter.com")
    @connection.client.debug_dev = nil
    structize(parse_response(res))
  end

  def search_result_to_hash(json)
    {
      'id' => json['id'],
      'text' => json['text'],
      'source' => json['source'],
      'created_at' => json['created_at'],
      'in_reply_to_user_id' => json['to_usre_id'],
      'in_reply_to_screen_name' => json['to_usre'],
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
    json_data = JSON.parse(res.content)
    case res.status.to_i
    when 200
      json_data
    else
      raise APIError.new(json_data['error'], res)
    end
  end

  def structize(data)
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
