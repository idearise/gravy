require 'rubygems'
require 'logger'
require 'rest_client'
require 'json'

$:.unshift(File.dirname(__FILE__)) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'gravy/gravy'

module Gravy
end