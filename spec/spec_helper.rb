# -*- coding: utf-8 -*-

$:.unshift(File.dirname(__FILE__) + '/../lib')
require 'rubytter'

class DummyResponse
  attr_accessor :status
  attr_accessor :content
  def initialize(status = 200, content = '{}')
    @status = status
    @content = content
  end
end
