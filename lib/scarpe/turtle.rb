# frozen_string_literal: true

# Turtle Graphics for Scarpe
#
# This file provides the `require 'scarpe/turtle'` entry point for turtle graphics.
# The actual implementation lives in Lacci (lacci/lib/shoes/turtle.rb).
#
# Usage:
#   require 'scarpe/turtle'
#
#   Turtle.draw do
#     forward 100
#     turnleft 90
#     forward 100
#   end
#
#   Turtle.start do
#     background blue
#     pencolor yellow
#     30.times { forward(rand(50)); turnleft(rand(360)) }
#   end

# Load the turtle implementation from Lacci
require_relative "../../lacci/lib/shoes/turtle"
