# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/../spec_helper'

class Rubytter::OAuth
  describe Rubytter::OAuth do
    context 'ca_file is not specified' do
      before do
        @oauth = Rubytter::OAuth.new('key', 'secret')
      end

      it 'should get_request_token' do
        # sample from OAuth 1.0 spec.
        @oauth.consumer.test_loopback_response << 'oauth_token=hh5s93j4hdidpola&oauth_token_secret=hdhd0244k9j7ao03'
        request_token = @oauth.get_request_token
        request_token.token.should == 'hh5s93j4hdidpola'
        request_token.secret.should == 'hdhd0244k9j7ao03'
      end

      it 'should get_access_token_with_xauth' do
        # sample from http://apiwiki.twitter.com/Twitter-REST-API-Method:-oauth-request_token
        @oauth.consumer.test_loopback_response << 'oauth_token=819797-torCkTs0XK7H2A2i1ee5iofqkMC4p7aayeEXRTmlw&oauth_token_secret=SpuaLXRxZ0gOZHNQKPooBiWC2RY81klw13kLZGa2wc&user_id=819797&screen_name=episod'

        token = @oauth.get_access_token_with_xauth('login', 'password')
        token.token.should == '819797-torCkTs0XK7H2A2i1ee5iofqkMC4p7aayeEXRTmlw'
        token.secret.should == 'SpuaLXRxZ0gOZHNQKPooBiWC2RY81klw13kLZGa2wc'
        token.params['user_id'].should == '819797'
        token.params['screen_name'].should == 'episod'
      end
    end

    context 'ca_file is specified' do
      it 'should load ca_file' do
        proc {
          Rubytter::OAuth.new('key', 'secret', __FILE__)
        }.should raise_error(OpenSSL::X509::StoreError)
      end
    end
  end
end
