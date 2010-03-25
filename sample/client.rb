require 'rubytter'

# OAuth example

# create your application at http://twitter.com/apps/new to retrieve consumer token.
consumer_key = 'key'
consumer_secret = 'secret'

oob_authorize_url = 'https://twitter.com/oauth/authorize'

# get request token
consumer = Rubytter::OAuth.new(consumer_key, consumer_secret)
request_token = consumer.get_request_token
token = request_token.token
secret = request_token.secret

# let your authorize request token. PIN code (verifier) required
puts "Go here and do confirm: #{oob_authorize_url}?oauth_token=#{token}"
puts "Type oauth_verifier/PIN (if given) and hit [enter] to go"
verifier = gets.chomp

# get access token
access_token = consumer.get_access_token(token, secret, verifier)
token = access_token.token
secret = access_token.secret

# initialize OAuthRubytter
rubytter = OAuthRubytter.new(:token => token, :secret => secret, :consumer => {:key => consumer_key, :secret => consumer_secret})

# for wiredump debugging
# rubytter.connection.client.debug_dev = STDERR

# sample API usage.
p rubytter.user_timeline(1).class
p rubytter.replies.class
p rubytter.search('ruby openssl')
p rubytter.search_user('nahi')
