# frozen_string_literal: true

require "ffi"
require 'ffi-compiler/loader'
require "json"
require_relative "webview_ruby/version"

module WebviewRuby
  extend FFI::Library
  ffi_lib FFI::Compiler::Loader.find('webview-ext')
  attach_function :webview_create, [:int, :pointer], :pointer
  attach_function :webview_run, [:pointer], :void
  attach_function :webview_terminate, [:pointer], :void
  attach_function :webview_set_title, [:pointer, :string], :void
  attach_function :webview_set_size, [:pointer, :int, :int, :int], :void
  attach_function :webview_navigate, [:pointer, :string], :void
  attach_function :webview_destroy, [:pointer], :void
  attach_function :webview_bind, [:pointer, :string, :pointer, :pointer], :void
  attach_function :webview_eval, [:pointer, :string], :void
  attach_function :webview_init, [:pointer, :string], :void

  class Webview
    attr_reader :is_running

    def initialize(debug:false)
      @is_running = false
      @bindings = {}
      @window = WebviewRuby.webview_create(debug ? 1 : 0, nil)
    end

    def set_title(title)
      WebviewRuby.webview_set_title(@window, title)
    end

    def set_size(width, height, hint=0)
      WebviewRuby.webview_set_size(@window, width, height, hint)
    end

    def navigate(page)
      WebviewRuby.webview_navigate(@window, page)
    end

    def run
      @is_running = true
      WebviewRuby.webview_run(@window)
    end

    def terminate
      @is_running = false
      WebviewRuby.webview_terminate(@window)
    end

    def destroy
      WebviewRuby.webview_destroy(@window)
    end

    def bind(name, func=nil, &block)
      callback = FFI::Function.new(:void, [:string, :string, :pointer]) do |seq, req, arg|
        begin 
          params = JSON.parse(req)
          if func
            func(*params)
          else
            block.call(*params)
          end
        rescue StandardError => e
          print("Error occured: #{e.full_message}. \n\n Going to terminate\n")
          terminate
        end
      end
      @bindings[callback] = true # save a reference
      WebviewRuby.webview_bind(@window, name, callback, nil)
    end

    def eval(js)
      WebviewRuby.webview_eval(@window, js)
    end

    def init(js)
      WebviewRuby.webview_init(@window, js)
    end
  end
end
