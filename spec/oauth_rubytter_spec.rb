# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/spec_helper'

class OAuthRubytter
  describe Rubytter do
    before do
      @rubytter = Rubytter.new('test', 'test')
    end

    it 'should post using access_token' do
      access_token = Object.new
      rubytter = OAuthRubytter.new(access_token)
      response = simple_mock(:body => '{}', :code => '200')
      access_token.should_receive(:post).with(
        "/statuses/update.json",
        {'status' => 'test'},
        {"User-Agent"=>"Rubytter/#{Rubytter::VERSION} (http://github.com/jugyo/rubytter)"}
      ).and_return(response)
      rubytter.update('test')
    end

    it 'should get using access_token' do
      access_token = Object.new
      rubytter = OAuthRubytter.new(access_token)
      response = simple_mock(:body => '{}', :code => '200')
      access_token.should_receive(:get).with(
        '/statuses/friends_timeline.json',
        {"User-Agent"=>"Rubytter/#{Rubytter::VERSION} (http://github.com/jugyo/rubytter)"}
      ).and_return(response)
      rubytter.friends_timeline
    end

    it 'should get with params using access_token' do
      access_token = Object.new
      rubytter = OAuthRubytter.new(access_token)
      response = simple_mock(:body => '{}', :code => '200')
      access_token.should_receive(:get).with(
        '/statuses/friends_timeline.json?page=2',
        {"User-Agent"=>"Rubytter/#{Rubytter::VERSION} (http://github.com/jugyo/rubytter)"}
      ).and_return(response)
      rubytter.friends_timeline(:page => 2)
    end

    def simple_mock(options)
      o = Object.new
      options.each do |k, v|
        o.should_receive(k).and_return(v)
      end
      o
    end
  end
end
