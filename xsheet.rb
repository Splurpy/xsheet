require './model.rb'
require './interp.rb'
require './tui.rb'

grid = Model::Grid.new()
runtime = Model::Runtime.new(grid)
evaluator = Model::Evaluator.new(runtime)

sheet = Sheet.new(runtime)
sheet.start_editor
