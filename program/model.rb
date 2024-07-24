module Model
  # Primitives Begin Here
  class Primitive
    attr_accessor :value, :i_start, :i_end

    def initialize(value, i_start, i_end)
      @value = value
      @i_start = i_start
      @i_end = i_end
    end

    def to_s()
      "#{@value}"
    end
  end

  class Numeric < Primitive
  end

  class Integer < Numeric
    def traverse(visitor, runtime)
      visitor.visit_int(self, runtime)
    end
  end

  class Float < Numeric
    def traverse(visitor, runtime)
      visitor.visit_float(self, runtime)
    end
  end

  class Bool < Primitive
    def traverse(visitor, runtime)
      visitor.visit_bool(self, runtime)
    end
  end

  class String < Primitive
    def traverse(visitor, runtime)
      visitor.visit_string(self, runtime)
    end
  end

  class CellAddr
    attr_reader :value

    def initialize(value)
      @value = value
    end

    # Holds array of numeric primitive types
    def traverse(visitor, runtime)
      visitor.visit_celladdr(self, runtime)
    end
  end

  # End Primitives, Begin Operations

  class UnaryOp
    attr_reader :operator, :operand, :i_start, :i_end

    def initialize(operator, operand, i_start, i_end)
      @operand = operand
      @operator = operator
      @i_start = i_start
      @i_end = i_end
    end

    def to_s()
      "#{@operator}(#{@operand})"
    end
  end

  class BinaryOp
    attr_reader :operand1, :operand2, :operator, :i_start, :i_end

    def initialize(operand1, operator, operand2, i_start, i_end)
      @operand1 = operand1
      @operand2 = operand2
      @operator = operator
      @i_start = i_start
      @i_end = i_end
    end

    def to_s()
      "#{@operand1} #{@operator} #{@operand2}"
    end
  end

  # Begin Unary Outliers

  class NegateOp < UnaryOp
    def traverse(visitor, runtime)
      visitor.visit_negation(self, runtime)
    end
  end

  class LogicNotOp < UnaryOp
    def traverse(visitor, runtime)
      visitor.visit_logic_not(self, runtime)
    end
  end

  class BitwiseNotOp < UnaryOp
    def traverse(visitor, runtime)
      visitor.visit_bitwise_not(self, runtime)
    end
  end

  # End Unary Outliers, Begin Vague Binary Operation Subclasses

  class ArithOp < BinaryOp
    def traverse(visitor, runtime)
      visitor.visit_arithmetic(self, runtime)
    end
  end

  class LogicOp < BinaryOp
    def traverse(visitor, runtime)
      visitor.visit_logical(self, runtime)
    end
  end

  class BitwiseOp < BinaryOp
    def traverse(visitor, runtime)
      visitor.visit_bitwise(self, runtime)
    end
  end

  class RelateOp < BinaryOp
    def traverse(visitor, runtime)
      visitor.visit_relation(self, runtime)
    end
  end

  # End Vague Binary Operation Subclasses, Begin Casting Operations
  class CastOp < UnaryOp
    def traverse(visitor, runtime)
      visitor.visit_cast(self, runtime)
    end
  end

  # End Casting Operations, Begin Cell Values
  class CellValue
    attr_reader :value, :i_start, :i_end

    def initialize(x_val, y_val, i_start, i_end)
      @value = [x_val, y_val]
      @i_start = i_start
      @i_end = i_end
    end
  end

  # Literal address of a cell (the address is what's important)
  class LValue < CellValue
    def traverse(visitor, runtime)
      visitor.visit_lvalue(self, runtime)
    end
  end

  # Reference to a cell's address (pertains to the actual value that cell evaluates to)
  class RValue < CellValue
    def traverse(visitor, runtime)
      visitor.visit_rvalue(self, runtime)
    end
  end

  # End Cell Values, Begin Stat Operation
  class StatOp < BinaryOp

    def traverse(visitor, runtime)
      visitor.visit_stat(self, runtime)
    end
  end

  # End Stat Operation

  # Begin Visitor Pattern Code

  # 1) Begin Serializer

  # This class is fairly straight forward, there's not much documentation below
  class Serializer

    def visit_int(node, runtime)
      return node.value.to_s
    end

    def visit_float(node, runtime)
      return node.value.to_s
    end

    def visit_bool(node, runtime)
      return node.value.to_s
    end

    def visit_string(node, runtime)
      return node.value.inspect
    end

    def visit_celladdr(node, runtime)
      return node.value
    end

    def visit_negation(node, runtime)
      return "(-#{node.operand.traverse(self, runtime)})"
    end

    def visit_logic_not(node, runtime)
      return "(!#{node.operand.traverse(self, runtime)})"
    end

    def visit_bitwise_not(node, runtime)
      return "(~#{node.operand.traverse(self, runtime)})"
    end

    def visit_arithmetic(node, runtime)
      return "(#{node.operand1.traverse(self, runtime)} #{node.operator.value} #{node.operand2.traverse(self, runtime)})"
    end

    def visit_logical(node, runtime)
      return "(#{node.operand1.traverse(self, runtime)} #{node.operator.value} #{node.operand2.traverse(self, runtime)})"
    end

    def visit_bitwise(node, runtime)
      return "(#{node.operand1.traverse(self, runtime)} #{node.operator.value} #{node.operand2.traverse(self, runtime)})"
    end

    def visit_relation(node, runtime)
      return "(#{node.operand1.traverse(self, runtime)} #{node.operator.value} #{node.operand2.traverse(self, runtime)})"
    end

    def visit_cast(node, runtime)
      return "#{node.operator.value}(#{node.operand.traverse(self, runtime)})"
    end

    def visit_lvalue(node, runtime)
      return "[#{node.value[0].traverse(self, runtime)}, #{node.value[1].traverse(self, runtime)}]"
    end

    def visit_rvalue(node, runtime)
      return "#[#{node.value[0].traverse(self, runtime)}, #{node.value[1].traverse(self, runtime)}]"
    end

    def visit_stat(node, runtime)
      return "#{node.operator.value}(#{node.operand1.traverse(self, runtime)}, #{node.operand2.traverse(self, runtime)})"
    end
  end

  # End Serializer

  # Utils for catching invalid CellAddr passes and raising exceptions
  class ModelUtils

    # Raise an appropriate error (EXCEPTION HANDLER)
    def self.raise_err(type, value) # EXCEPTIONS
      val_type = value.nil? ? nil : value.class.name
      # Check if actual_type is nil, if so, "one or more operands", if not, be specific
      case type
      when "arith"
        err_msg = (value.is_a? ArithOp) ? "One or more operands are of Illegal type (must be Numeric)" : "Illegal operand - Passed: <#{val_type}> (must be Numeric)"
        err_msg += " @ index #{value.i_start}"
        raise TypeError, err_msg
      when "zero"
        raise ZeroDivisionError, "Illegal operation - division by zero @ index #{value.i_start}"
      when "logic"
        err_msg = val_type.nil? ? "One or more operands are of Illegal type (must be Boolean)" : "Illegal operand - Passed: <#{val_type}> (must be Boolean)"
        raise TypeError, err_msg
      when "bit"
        err_msg = val_type.nil? ? "One or more operands are of Illegal type (must be Integer)" : "Illegal operand - Passed: <#{val_type}> (must be Integer) @ index #{value.i_start}"
        raise TypeError, err_msg
      when "relate"
        err_msg = val_type.nil? ? "One or more operands are of Illegal type (must be Numeric)" : "Illegal operand - Passed: <#{val_type}> (must be Numeric)"
        raise TypeError, err_msg
      when "cast"
        err_msg = !(value.is_a? Numeric) ? "One or more operands are of Illegal type (must be Numeric)" : "Illegal operand - Passed: <#{val_type}> (must be Numeric)"
        err_msg += " @ index #{value.i_start}"
        raise TypeError, err_msg
      when "cast_i"
        err_msg = val_type.nil? ? "Operand is nil" : "Illegal operand - Passed: <#{val_type}> (must be Float) @ index #{value.i_start}"
        raise TypeError, err_msg
      when "cast_f"
        err_msg = val_type.nil? ? "Operand is nil" : "Illegal operand - Passed: <#{val_type}> (must be Integer) @ index #{value.i_start}"
        raise TypeError, err_msg
      when "stat"
        err_msg = val_type.nil? ? "One or more operands are of Illegal type (must be LValue / CellAddr)" : "Illegal operand - Passed: <#{val_type}> (must be LValue)"
        raise TypeError, err_msg
      when "undef_cell"
        err_msg = "Attempting to access an undefined cell @ CellAddress <#{value}>"
        raise RuntimeError, err_msg
      when "addr"
        err_msg = "Illegal Argument - Passed: <#{value}> of type <#{val_type}> (must be CellAddr)"
        raise ArgumentError, err_msg
      when "stat_area"
        err_msg = "Incompatible type in target area - Accessed: <#{value}> of type <#{val_type}> (must be Numeric)"
        raise RuntimeError, err_msg
      end
    end

    # Simple check and exception throw if CellAddr's aren't actually CellAddr
    def self.catch_address(address)
      if !address.is_a? CellAddr
        raise_err("addr", address)
      end
    end
  end

  # 2) Begin Evaluator
  class Evaluator

    def initialize(runtime)
    end

    # Begin Traversal Methods
    def evaluate(node, runtime)
      node.traverse(self, runtime)
    end

    def visit_int(node, runtime)
      node
    end

    def visit_float(node, runtime)
      node
    end

    def visit_bool(node, runtime)
      # puts "visiting bool with value <#{node.value}> | i_start = <#{node.i_start}>"
      node
    end

    def visit_string(node, runtime)
      node
    end

    def visit_celladdr(node, runtime)
      node
    end

    def visit_negation(node, runtime)
      op_value = evaluate(node.operand, runtime)
      # Construct the proper mode primitive
      (op_value.is_a? Numeric) ? ((op_value.is_a? Integer) ? Integer.new(-op_value.value, 0, 0) : Float.new(-op_value.value, 0, 0)) : ModelUtils.raise_err('arith', op_value)
    end

    def visit_logic_not(node, runtime)
      op_value = evaluate(node.operand, runtime)
      (op_value.is_a? Bool) ? Bool.new(!op_value.value, 0, 0) : ModelUtils.raise_err('logic', op_value)
    end

    def visit_bitwise_not(node, runtime)
      op_value = evaluate(node.operand, runtime)
      (op_value.is_a? Integer) ? Integer.new(~op_value.value, 0, 0) : ModelUtils.raise_err('bit', op_value)
    end

    def visit_arithmetic(node, runtime)
      op1_value = evaluate(node.operand1, runtime)
      op2_value = evaluate(node.operand2, runtime)

      # Arithmetic Calculation (Except Negation)
      # This uses the "value" state (raw values) and then instantiates a new primitive
      if !((op1_value.is_a? Numeric) && (op2_value.is_a? Numeric)) then ModelUtils.raise_err('arith', node) end

      # Get Ruby primitive values
      op1_value = op1_value.value
      op2_value = op2_value.value

      case node.operator.value
      when '+'
        result = op1_value + op2_value
      when '-'
        result = op1_value - op2_value
      when '*'
        result = op1_value * op2_value
      when '/'
        (op2_value != 0 ? (result = op1_value / op2_value) : ModelUtils.raise_err('zero', node.operand2))
      when '%'
        (op2_value != 0 ? (result = op1_value % op2_value) : ModelUtils.raise_err('zero', node.operand2))
      when '**'
        result = op1_value ** op2_value
      end

      (result.is_a? ::Integer) ? result = Integer.new(result, node.i_start, node.i_start + result.abs.digits.count) : result = Float.new(result, node.i_start, node.i_start)
      return result
    end

    def visit_logical(node, runtime)
      op1_value = evaluate(node.operand1, runtime)
      op2_value = evaluate(node.operand2, runtime)
      if !((op1_value.is_a? Bool) && (op2_value.is_a? Bool)) then ModelUtils.raise_err('logic', nil) end

      # Get Ruby primitive values
      op1_value = op1_value.value
      op2_value = op2_value.value

      case node.operator.value
      when '&&'
        result = op1_value && op2_value
      when '||'
        result = op1_value || op2_value
      end

      Model::Bool.new(result, 0, 0)
    end

    def visit_bitwise(node, runtime)
      op1_value = evaluate(node.operand1, runtime)
      op2_value = evaluate(node.operand2, runtime)
      # puts "op1_value = <#{op1_value.value}> | i_start = <#{op1_value.i_start}>"
      # puts "op2_value = <#{op2_value.value}> | i_start = <#{op2_value.i_start}>"
      if !((op1_value.is_a? Integer) && (op2_value.is_a? Integer)) then ModelUtils.raise_err('bit', (
        op1_value.is_a?(Integer) ? op2_value : op1_value
      )) end

      # Get Ruby primitive values
      op1_value = op1_value.value
      op2_value = op2_value.value

      case node.operator.value
      when '&'
        result = op1_value & op2_value
      when '|'
        result = op1_value | op2_value
      when '^'
        result = op1_value ^ op2_value
      when '<<'
        result = op1_value << op2_value
      when '>>'
        # puts "#{op1_value} >> #{op2_value} = #{op1_value >> op2_value}"
        result = op1_value >> op2_value
      end

      return Integer.new(result, 0, result.to_s.length)
    end

    def visit_relation(node, runtime)
      op1_value = evaluate(node.operand1, runtime)
      op2_value = evaluate(node.operand2, runtime)
      if !((op1_value.is_a? Numeric) && (op2_value.is_a? Numeric)) then ModelUtils.raise_err('relate', nil) end

      # Get Ruby primitive values
      op1_value = op1_value.value
      op2_value = op2_value.value

      case node.operator.value
      when '=='
        result = op1_value == op2_value
      when '!='
        result = op1_value != op2_value
      when '<'
        result = op1_value < op2_value
      when '<='
        result = op1_value <= op2_value
      when '>'
        result = op1_value > op2_value
      when '>='
        result = op1_value >= op2_value
      end

      result = Bool.new(result, 0, 0)
    end

    def visit_cast(node, runtime)
      op_value = evaluate(node.operand, runtime)
      if !(op_value.is_a? Numeric) then ModelUtils.raise_err('cast', op_value) end

      # Get operand
      op = op_value

      # Get operator
      operator = node.operator.value

      # Easier to look at/comprehend conditional
      if ((op.is_a? Integer )&& operator == 'to_f')
        return Float.new(op.value.to_f, 0, 0)
      elsif ((op.is_a? Float) && operator == 'to_i')
        Integer.new(op.value.to_i, 0, 0)
      elsif op.is_a? Integer
        ModelUtils.raise_err('cast_i', op)
      else
        ModelUtils.raise_err('cast_f', op)
      end
    end

    def visit_lvalue(node, runtime)
      x = evaluate(node.value[0], runtime)
      y = evaluate(node.value[1], runtime)
      return CellAddr.new([x, y])
    end

    def visit_rvalue(node, runtime)
      # puts "visiting RValue with value <#{node.value}> | i_start = <#{node.i_start}>"
      x = evaluate(node.value[0], runtime)
      y = evaluate(node.value[1], runtime)
      addr = CellAddr.new([x, y])
      # Ensure that rvalues evaluate to their "pointee"
      result = evaluate(runtime.get_cell(addr), runtime)
      result.i_start = node.i_start
      puts "RValue evaluated to <#{result}> | i_start = <#{result.i_start}>"
      result
    end

    def visit_stat(node, runtime)
      op1_value = evaluate(node.operand1, runtime)
      op2_value = evaluate(node.operand2, runtime)

      # Convert the cell addresses to LValues if necessary
      if op1_value.is_a? CellAddr
        op1_value = LValue.new(op1_value.value[0], op1_value.value[1], node.operand1.i_start, node.operand1.i_end)
      end

      # More conversion
      if op2_value.is_a? CellAddr
        op2_value = LValue.new(op2_value.value[0], op2_value.value[1], node.operand2.i_start, node.operand2.i_end)
      end

      if !((op1_value.is_a? LValue) && (op2_value.is_a? LValue)) then ModelUtils.raise_err('stat', nil) end

      # Initialize result as zero for mean and sum
      result = 0

      # Reduce code clutter, repetition, and ambiguity by naming "pieces" of data
      cell1 = op1_value
      cell2 = op2_value

      cell1_x = cell1.value[0].value
      cell1_y = cell1.value[1].value

      cell2_x = cell2.value[0].value
      cell2_y = cell2.value[1].value

      # Initialize num_cells for mean, and pivot for min/max operations
      num_cells = 0
      pivot = nil

      # Create a new evaluator and pass it the existing runtime
      evaluator = Evaluator.new(runtime)
      # Filter the cells (there is probably a better way to do this, and in fact, this may be different down the line)
      runtime.grid.cells.filter do |addr, cell|
        x, y = addr
        # Only include the cell if it is within the target area (between cell1 and cell2)
        if (x >= cell1_x && x <= cell2_x) && (y >= cell1_y && y <= cell2_y)

          # Increment num_cells properly iterated through
          num_cells += 1

          # Again, naming "pieces" of data to avoid overcomplication and repetition
          cell_value = runtime.get_cell(CellAddr.new([Integer.new(x, 0, 0), Integer.new(y, 0, 0)])).traverse(evaluator, runtime)
          if !(cell_value.is_a? Numeric) then ModelUtils.raise_err('stat_area', cell_value) end

          # raw_value is just the language (ruby) primitive value contained within a model primitive
          raw_value = (cell_value.traverse(evaluator, runtime).value)

          # "Switch" over the ruby primitive contained within this StatOp's operator state, performing the required logic
          case node.operator.value
          when 'max'
            if pivot.nil? then pivot = raw_value
            elsif raw_value > pivot then pivot = raw_value end
          when 'min'
            if pivot.nil? then pivot = raw_value
            elsif raw_value < pivot then pivot = raw_value end
          when 'mean'
            operation = (result += raw_value)
          when 'sum'
            operation = (result += raw_value)
          end
        end
      end
      # Avoid division by zero (just in case)
      if node.operator.value == 'mean' then result /= (num_cells != 0 ? num_cells : 1) end
      if node.operator.value == 'min' || node.operator.value == 'max' then result = pivot end

      # Return the properly-typed model primitive
      (result.is_a? ::Integer) ? (return Integer.new(result, 0, 0)) : (return Float.new(result, 0, 0))
    end
  end

  # End Evaluator

  # Begin Cell Abstraction
  class Cell
    attr_reader :source, :tree, :evaluated_to

    def initialize(source, tree, evaluated_to)
      @source = source
      @tree = tree
      @evaluated_to = evaluated_to
    end

    def to_s()
      "[Tree: <#{serialize(@tree)}>, Evals_to: <#{@evaluated_to}>]"
    end

    # Serialize the tree
    def serialize(tree)
      # Create a serializer and traverse the tree
      serializer = Model::Serializer.new()
      result = tree.traverse(serializer, nil)

      # Return the serialized result
      result
    end
  end

  # End Cell Abstraction

  # Begin Grid and Runtime Abstractions
  class Grid
    attr_reader :cells

    def initialize()
      @cells = {}
    end

    # Set a cell in the grid
    def set_cell(address, tree)
      runtime = Runtime.new(self)
      evaluator = Evaluator.new(runtime)
      eval_to = tree.traverse(evaluator, runtime)
      # Ensure the proper "key" is added to the "cells" hash
      addr_eval = [address.value[0].value, address.value[1].value]

      @cells[addr_eval] = Cell.new(nil, tree, eval_to)
    end

    # Get the cell's value
    def get_cell(address, runtime)
      evaluator = Evaluator.new(runtime)
      # Ensure the proper "key" is used when searching "cells"
      addr_eval = [address.value[0].value, address.value[1].value]
      if @cells.include?(addr_eval)
        set_cell(address, @cells[addr_eval].tree)
        # puts "cell #{addr_eval} = <#{@cells[addr_eval].tree}>"
        # puts "cell #{addr_eval}.i_start = <#{@cells[addr_eval].tree.i_start}>"
        @cells[addr_eval].evaluated_to
      else
        ModelUtils.raise_err('undef_cell', addr_eval)
      end
    end

    # Remove a cell from the grid
    def remove_cell(address)
      if has?(address)
        @cells.delete([address.value[0].value, address.value[1].value])
      end
    end

    # If the grid contains the cell at the specified address
    def has?(address)
      @cells.include?([address.value[0].value, address.value[1].value])
    end
  end

  # End Grid

  # Begin Runtime
  class Runtime

    # Reachable via "runtime_name".(globals / locals)["target global"]
    # globals and locals may be modified in the future, base stub implementation follows
    attr_reader :grid, :globals, :locals

    def initialize(grid)
      @grid = grid # Grid instance
      @globals = {} # Transient global states
      @locals = {} # Transient local states
    end

    def grab_global(key)
      @globals[key]
    end

    def grab_local(key)
      @locals[key]
    end

    # Query the grid to set a cell
    def set_cell(address, tree)
      ModelUtils.catch_address(address)
      @grid.set_cell(address, tree)
    end

    # Query the grid to get a cell's evaluation
    def get_cell(address)
      ModelUtils.catch_address(address)
      @grid.get_cell(address, self)
    end

    # Query the grid to remove a cell
    def remove_cell(address)
      @grid.remove_cell(address)
    end

    # Clear all data within the grid
    def reset()
      @globals = {}
      @locals = {}
      @grid = Grid.new()
    end

    # Get complete hash of cells from grid (For debugging)
    def cells()
      @grid.cells
    end
  end

  # End Runtime
end
