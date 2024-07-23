# Namespace for Interpreter (Token, Lexer, Parser)
module Interp
  # Token Abstraction
  class Token
    # Reader for instance states
    attr_reader :type, :source, :i_start, :i_end

    # Simple constructor
    def initialize(type, source, i_start, i_end)
      @type = type
      @source = source
      @i_start = i_start
      @i_end = i_end
    end

    # Override default to_string for debugging
    def to_s
      "Token -> [#{@type}, \"#{@source}\", #{@i_start}, #{@i_end}]"
    end
  end

  # Lexer Implementation
  class Lexer
    # Simple constructor
    def initialize(source)
      @source = source
      @pos = 0
      @tokens = []
      @token_so_far= ''
    end

    # Actual lexing method
    def lex
      while @pos < @source.length
        if has('(')
          capture()
          emit_token(:left_paren)
        elsif has(')')
          capture()
          emit_token(:right_paren)
        elsif has('#')
          capture()
          emit_token(:hashtag)
        elsif has('[')
          capture()
          emit_token(:left_bracket)
        elsif has(']')
          capture()
          emit_token(:right_bracket)
        elsif has(',')
          capture()
          emit_token(:comma)
        elsif has('+')
          capture()
          emit_token(:plus)
        elsif has('-') # Negative numbers and the arithmetic negation operator
          capture()
          if has_number()
            capture()
            while has_number
              capture()
            end
            # If this number is a float
            if has('.')
              capture()
              while has_number
                capture()
              end
              emit_token(:float_literal)
            else
              emit_token(:integer_literal)
            end
          else
            emit_token(:minus)
          end
        elsif has_number() # Positive numbers
          capture()
          while has_number
            capture()
          end
          # If this number is a float
          if has('.')
            capture()
            while has_number
              capture()
            end
            emit_token(:float_literal)
          else
            emit_token(:integer_literal)
          end
        elsif has('*')
          capture()
          if has('*')
            capture()
            emit_token(:raise)
          else
            emit_token(:asterisk)
          end
        elsif has('/')
          capture()
          emit_token(:div)
        elsif has('%')
          capture()
          emit_token(:modulo)
        elsif has('^')
          capture()
          emit_token(:caret)
        elsif has('!')
          capture()
          if has('=')
            capture()
            emit_token(:not_equal)
          else
            emit_token(:logic_not)
          end
        elsif has('<')
          capture()
          if has('=')
            capture()
            emit_token(:less_equal)
          elsif has('<')
            capture()
            emit_token(:left_shift)
            # puts "Found left shift"
          else
            emit_token(:less_than)
          end
        elsif has('>')
          capture()
          if has('=')
            capture()
            emit_token(:greater_equal)
          elsif has('>')
            capture()
            emit_token(:right_shift)
            # puts "Found right shift"
          else
            emit_token(:greater_than)
          end
        elsif has('=')
          capture()
          if has('=')
            capture()
            emit_token(:equal_to)
          else
            abandon()
            # Skip these
          end
        elsif has('&')
          capture()
          if has('&')
            capture()
            emit_token(:logic_and)
            # puts "Found logic_and"
          else
            emit_token(:bitwise_and)
          end
        elsif has('|')
          capture()
          if has('|')
            capture()
            emit_token(:or)
          else
            emit_token(:bitwise_or)
          end
        elsif has_letter
          capture()
          while has_letter
            capture()
          end
          if @token_so_far == 'to_i'
            emit_token(:cast_int)
          elsif @token_so_far == 'to_f'
            emit_token(:cast_float)
          elsif @token_so_far == 'min'
            emit_token(:min)
          elsif @token_so_far == 'max'
            # puts "Found max op"
            emit_token(:max)
          elsif @token_so_far == 'mean'
            emit_token(:mean)
          elsif @token_so_far == 'sum'
            emit_token(:sum)
          elsif @token_so_far == 'true' || @token_so_far == 'false'
            emit_token(:bool_literal)
          else
            # In preparation for further milestones (namely milestone 4)
            emit_token(:indentifier)
          end
        elsif has(' ')
          # Skip whitespace
          abandon()
        else
          raise SyntaxError, "Invalid Syntax: Unrecognized token {#{@source[@pos]}} @ index #{@pos}"
        end
      end

      @tokens
    end

    # Is the current character a letter or underscore?
    def has_letter()
      (@pos < @source.length && @source[@pos] >= 'a' && @source[@pos] <= 'z') || @source[@pos] == '_'
    end

    # Is the current character a number?
    def has_number()
      @pos < @source.length && @source[@pos].match(/[0-9]/)
    end

    # Is the current character "char"?
    def has(char)
      @pos < @source.length && @source[@pos] == char
    end

    # Add the current character to @token_so_far and advance the lexer
    def capture()
      @token_so_far += @source[@pos]
      @pos += 1
    end

    # Wipe the existing @token_so_far and advance the lexer
    def abandon()
      @token_so_far = ''
      @pos += 1
    end

    # "Export" the current @token_so_far to @tokens, wiping @token_so_far in the process
    def emit_token(type)
      @tokens.push(Token.new(type, @token_so_far, @pos - @token_so_far.length, @pos - 1))
      # puts "Emitting token of type <#{type}> | i_start = <#{@pos - @token_so_far.length}>"
      @token_so_far = ''
    end
  end

  # Complete Parser Implementation
  class Parser
    # Simple constructor
    def initialize(tokens)
      @tokens = tokens
      @pos = 0
      @curr = get_curr_token()
    end

    def get_curr_token()
      @tokens[@pos]
    end

    # Actual parsing method
    def parse
      result = parse_expression
      if @pos < (@tokens.length - 1)
        # puts @tokens.join(" ")
        raise SyntaxError, "!Extraneous Tokens! -- <#{(@tokens.map {|token| token.source}).join(' ')}>"
      end
      result
    end

    private

    # Parse an expression
    def parse_expression
      parse_binary_operation
    end

    # Parse a binary operation
    def parse_binary_operation
      if has(:left_paren)
        advance
        left_operand = parse_binary_operation
        expect(:right_paren)
      elsif has_stat_operation
        # puts "Found stat operator"
        stat_op = @curr
        advance
        expect(:left_paren)
        left_bracket = @curr
        advance
        x_value = parse_expression
        expect(:comma)
        y_value = parse_expression
        expect(:right_bracket)
        # puts "arg1 -> [#{x_value.value}, #{y_value.value}]"
        expect(:comma)
        expect(:left_bracket)
        x_value_2 = parse_expression
        expect(:comma)
        y_value_2 = parse_expression
        # puts "arg2 -> [#{x_value_2.value}, #{y_value_2.value}]"
        expect(:right_bracket)
        expect(:right_paren)
        left_operand = Model::StatOp.new(
          Model::LValue.new(x_value, y_value, x_value.i_start - 1, y_value.i_end + 1),
          Model::String.new(stat_op.source, stat_op.i_start, stat_op.i_end),
          Model::LValue.new(x_value_2, y_value_2, x_value_2.i_start - 1, y_value_2.i_end + 1),
          stat_op.i_start, y_value_2.i_end + 2
        )
      else
        left_operand = parse_primitive_or_unary_operation
      end

      while @curr && is_binary_operator?(@curr.type)
        operator = @curr
        # puts "parsing - operator source is #{operator.source}"
        advance

        if has(:left_paren)
          advance
          right_operand = parse_binary_operation
          expect(:right_paren)
        elsif has_stat_operation # Check if the current token is a stat operation
          stat_op = @curr
          advance
          expect(:left_paren)
          left_bracket = @curr
          advance
          x_value = parse_expression
          expect(:comma)
          y_value = parse_expression
          expect(:right_bracket)
          # puts "arg1 -> [#{x_value.value}, #{y_value.value}]"
          expect(:comma)
          expect(:left_bracket)
          x_value_2 = parse_expression
          expect(:comma)
          y_value_2 = parse_expression
          # puts "arg2 -> [#{x_value_2.value}, #{y_value_2.value}]"
          expect(:right_bracket)
          expect(:right_paren)
          right_operand = Model::StatOp.new(
            Model::LValue.new(x_value, y_value, x_value.i_start - 1, y_value.i_end + 1),
            Model::String.new(stat_op.source, stat_op.i_start, stat_op.i_end),
            Model::LValue.new(x_value_2, y_value_2, x_value_2.i_start - 1, y_value_2.i_end + 1),
            stat_op.i_start, y_value_2.i_end + 2
          )
        else
          right_operand = parse_primitive_or_unary_operation
        end

        operation_type = case operator.type
                         when :plus
                           Model::ArithOp
                         when :minus
                           Model::ArithOp
                         when :asterisk
                           Model::ArithOp
                         when :raise
                          Model::ArithOp
                         when :div
                           Model::ArithOp
                         when :modulo
                           Model::ArithOp
                         when :caret
                           Model::BitwiseOp
                         when :not_equal
                           Model::RelateOp
                         when :less_than
                           Model::RelateOp
                         when :greater_than
                           Model::RelateOp
                         when :less_equal
                           Model::RelateOp
                         when :greater_equal
                           Model::RelateOp
                         when :equal_to
                           Model::RelateOp
                         when :logic_and
                           Model::LogicOp
                         when :bitwise_and
                          Model::BitwiseOp
                         when :left_shift
                          Model::BitwiseOp
                         when :right_shift
                          Model::BitwiseOp
                         when :bitwise_or
                          Model::BitwiseOp
                         when :or
                           Model::LogicOp
                         else
                           raise SyntaxError, "Unrecognized operator, got #{operator.source} @ index #{@curr&.i_start}"
                         end

        if [:min, :max, :mean, :sum].include?(operator.type)
          operator_value = Model::String.new(operator.source, operator.i_start, operator.i_end)
          left_operand = operation_type.new(left_operand, operator_value, right_operand, left_operand.i_start, right_operand.i_end)
        else
          left_operand = operation_type.new(left_operand, Model::String.new(operator.source, operator.i_start, operator.i_end), right_operand, left_operand.i_start, right_operand.i_end)
        end
      end

      left_operand
    end

    # Parse a primitive or unary operation
    def parse_primitive_or_unary_operation
      if has_unary_operator?
        operator = @curr
        advance
        if [:cast_float, :cast_int].include?(operator.type)
          expect(:left_paren)
          operand = parse_expression
          expect(:right_paren)
          cast_type = case operator.type
                      when :cast_float
                        Model::String.new('to_f', operator.i_start, operator.i_end)
                      when :cast_int
                        Model::String.new('to_i', operator.i_start, operator.i_end)
                      else
                        raise SyntaxError, "Unexpected unary operator, got #{operator.source} @ index #{@curr&.i_start}"
                      end
          return Model::CastOp.new(cast_type, operand, operand.i_start, operand.i_end)
        else
          expect(:left_paren)
          operand = parse_expression
          expect(:right_paren)
        end
        operation_type = case operator.type
                         when :minus
                           Model::NegateOp
                         when :logic_not
                           Model::LogicNotOp
                         when :bitwise_not
                           Model::BitwiseNotOp
                         else
                           raise SyntaxError, "Unexpected unary operator, got #{operator.source} @ index #{@curr&.i_start}"
                         end
        return operation_type.new(operator, operand, operator.i_start, operand.i_end)
      elsif has_cell_value?
        parse_cell_value
      elsif has_primitive?
        return parse_primitive
      else
        if @curr.nil?
          if @tokens[@pos - 1].nil?
            index_num = @pos
          else
            index_num = @tokens[@pos - 1].i_end + 1
          end
        else
          index_num = @curr&.i_start
        end
        raise SyntaxError, "Expected a primitive, unary operation, or cell value @ index #{index_num}"
      end
    end

    # Parse a cell value
    def parse_cell_value
      if has(:hashtag)
        i_start = @curr.i_start
        advance
        expect(:left_bracket)
        x_value = parse_expression
        expect(:minus) if has(:minus) # Check for the comma or minus before parsing the y-value
        expect(:comma)
        y_value = parse_expression
        expect(:right_bracket)
        # puts "Parsed RValue <[#{x_value}, #{y_value}]> | i_start = <#{i_start}>"
        return Model::RValue.new(x_value, y_value, i_start, y_value&.i_end)
      else
        expect(:left_bracket)
        x_value = parse_expression
        expect(:minus) if has(:minus) # Check for the comma or minus before parsing the y-value
        expect(:comma)
        y_value = parse_expression
        expect(:right_bracket)
        return Model::LValue.new(x_value, y_value, x_value&.i_start, y_value&.i_end)
      end
    end

    # Parse a primitive
    def parse_primitive
      case @curr&.type
      when :integer_literal
        Model::Integer.new(@curr.source.to_i, @curr.i_start, @curr.i_end)
      when :float_literal
        Model::Float.new(@curr.source.to_f, @curr.i_start, @curr.i_end)
      when :bool_literal
        Model::Bool.new(@curr.source == "true", @curr.i_start, @curr.i_end)
      else
        raise SyntaxError, "Invalid token type, got #{@curr} @ index #{@curr.i_start}" # Does not need to be handled by TUI
      end.tap { advance }
    end

    # Helper methods

    # Advance the parser forward in @tokens
    def advance(offset = 1)
      @pos += offset
      @curr = @tokens[@pos]
    end

    # Does @curr match the expected type?
    def has(type)
      @curr && @curr&.type == type
    end

    # Is the current token a number?
    def has_number()
      @curr && %i[integer_literal float_literal].include?(@curr.type)
    end

    # Is the current token a primitive data type?
    def has_primitive?
      @curr && %i[integer_literal float_literal bool_literal].include?(@curr.type)
    end

    # Is the current token a unary operator?
    def has_unary_operator?
      @curr && %i[minus logic_not bitwise_not cast_float cast_int].include?(@curr.type)
    end

    # Is the current token a binary operator?
    def is_binary_operator?(type)
      @curr && %i[plus minus asterisk div modulo caret not_equal less_than greater_than less_equal greater_equal equal_to or logic_and left_shift right_shift bitwise_and bitwise_or raise min max mean sum].include?(type)
    end

    # Is the current token a cell value
    def has_cell_value?
      has(:hashtag) || has(:left_bracket)
    end

    # Is the current token a statistical operation?
    def has_stat_operation
        @curr && [:min, :max, :mean, :sum].include?(@curr.type)
    end

    # Does @curr match the expected type and advances the parser?
    def expect(expected_type)
      if !has(expected_type)
        if @curr.nil?
          if @tokens[@pos - 1].nil?
            index_num = @pos
          else
            index_num = @tokens[@pos - 1].i_end + 1
          end
        else
          index_num = @curr&.i_start
        end
        raise SyntaxError, "Expected token of type #{expected_type} @ index #{index_num}"
      end
      advance
    end
  end # End Parser

end # End Module
