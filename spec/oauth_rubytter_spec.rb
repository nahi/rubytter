# -*- coding: utf-8 -*-

require File.dirname(__FILE__) + '/spec_helper'

class OAuthRubytter
  describe Rubytter do
    before do
      @rubytter = Rubytter.new(:user_name => 'test', :password => 'test')
    end

    it 'should post using access_token' do
      rubytter = OAuthRubytter.new
      response = simple_mock(:content => '{}', :status => '200')
      rubytter.connection.should_receive(:post).with(
        "/statuses/update.json",
        {:status => 'test'},
        {}
      ).and_return(response)
      rubytter.update('test')
    end

    it 'should get using access_token' do
      rubytter = OAuthRubytter.new
      response = simple_mock(:content => '{}', :status => '200')
      rubytter.connection.should_receive(:get).with(
        '/statuses/friends_timeline.json',
        {},
        {}
      ).and_return(response)
      rubytter.friends_timeline
    end

    it 'should get with params using access_token' do
      rubytter = OAuthRubytter.new
      response = simple_mock(:content => '{}', :status => '200')
      rubytter.connection.should_receive(:get).with(
        '/statuses/friends_timeline.json',
        {:page => 2},
        {}
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
