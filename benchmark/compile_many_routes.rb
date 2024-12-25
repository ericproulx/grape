# frozen_string_literal: true

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
require 'grape'
require 'benchmark/ips'
require 'memory_profiler'

MemoryProfiler.report(allow_files: 'grape') do
  class API < Grape::API
    prefix :api
    version 'v1', using: :path

    2000.times do |index|
      params do
        requires "hello#{index}", type: String
      end
      get "/test#{index}/" do
        'hello'
      end
    end
  end


  API.compile!
end.pretty_print(to_file: 'coerce.txt')
