# frozen_string_literal: true

require 'openstudio'

# Simply test the example model
OpenStudio::Model.exampleModel.save(OpenStudio::Path.new('in.osm'), true)
