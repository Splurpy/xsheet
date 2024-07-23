require 'curses'
require './model.rb'

class Sheet

  Cell = Struct.new(:col, :row)

  def initialize(runtime)
    @rows = 10
    @cols = 10
    @sheet_data = Array.new(@rows) { Array.new(@cols, '') }
    @mode = 'view'
    @curr = Cell.new(0, 0)

    @runtime = runtime
  end

  # Populate the given cell with its matching (if applicable) value
  # Also handle erroneous values
  def pop(col, row)
    begin
      value = inspect(@runtime.get_cell(address(col, row)))
      puts "P - Successfully evaluated <[#{col}, #{row}]>"
    rescue RuntimeError => re
      # puts "RUNTIME ERROR IN POP - <[#{col}, #{row}]>"
      if @sheet_data[col][row] != ''
        puts "RUNTIME CELL IS NIL / BUT NOT SHEET CELL - <[#{col}, #{row}]>"
        value = "ERROR"
      else
        # puts "Cell <[#{col}, #{row}]> is empty"
        value = ''
      end
    end

    # puts "POP - value is --> <#{value}>"

    # puts "<#{value[17..26]}> is value[17..26]"
    if value[17..26] == "undefined"
      puts "UNDEF ERROR AT <[#{col}, #{row}]>"
      begin
        add_to_sheet_at(@sheet_data[col][row], col, row)
        value = 'ERROR'
      rescue RuntimeError => re
        value = 'ERROR'
      end
    elsif value[0] == '<'
      puts "TYPE ERROR AT <[#{col}, #{row}]>"
      begin
        add_to_sheet_at(@sheet_data[col][row], col, row)
        value = 'ERROR'
      rescue TypeError => te
        value = 'ERROR'
      end
    elsif value[0..11] == 'Illegal Zero'
      begin
        add_to_sheet_at(@sheet_data[col][row], col, row)
        value = 'ERROR'
      rescue ZeroDivisionError => zde
        value = 'ERROR'
      end
    elsif (value[0..6] == "Invalid") || (value[0..7] == "Expected") || (value[0..19] == "Unrecognized Token {")
      # puts "Syntax error?? - value is #{value}"
      begin
        add_to_sheet_at(@sheet_data[col][row], col, row)
        value = 'ERROR'
      rescue SyntaxError => se
        value = 'ERROR'
      end
    end

    if value.nil?
      puts "VALUE IS NIL"
      add_to_sheet(@sheet_data[@curr.col][@curr.row])
      value = retry_pop(col, row)
    else
      if value.length > 7
        value = (value[0, 5] + '..')
      elsif value.length == 0
        value = ''
      end
    end
    value.center(9)
  end

  # Retry populating a cell, populate the error message if needed
  def retry_pop(col, row)
    begin
      value = inspect(@runtime.get_cell(address(col, row)))
      puts "RP - Successfully evaluated <[#{col}, #{row}]>"
    rescue RuntimeError => re
      puts "RUNTIME ERROR IN RETRY_POP"
      value = 'ERROR'
    rescue TypeError => te
      puts "TYPE ERROR IN RETRY_POP"
      value = 'ERROR'
    rescue ZeroDivisionError => zde
      puts "ZERODIV ERROR IN RETRY_POP"
      value = "ERROR"
    rescue SyntaxError => se
      puts "SYNTAX ERROR IN RETRY_POP"
      value = "ERROR"
    end
    value
  end

  # Populate the "value" field with the cell's full value
  def pop_value()
    begin
      value = inspect(@runtime.get_cell(address(@curr.col, @curr.row)))
      puts "Successfully evaluated <[#{@curr.col}, #{@curr.row}]>"
    rescue RuntimeError => re
      if @runtime.grid.has?(address(@curr.col, @curr.row))
        # Attempting to access an undefined cell
        if re.message[0..51] == "Attempting to access an undefined cell @ CellAddress"
          value = "Cell #{re.message[53..re.message.length - 1]} is undefined"
        else
          value = 'non-access error'
          puts re.message
        end
      elsif (!(@runtime.grid.has?(address(@curr.col, @curr.row))) && @sheet_data[@curr.col][@curr.row] != '')
        begin
          add_to_sheet_at(@curr.col, @curr.row, @sheet_data[@curr.col][@curr.row])
        rescue RuntimeError => re
          if re.message[0..51] == "Attempting to access an undefined cell @ CellAddress"
            value = "Cell #{re.message[53..re.message.length - 1]} is undefined"
            # puts re.message
          else
            value = 'non-access error'
            puts re.message
          end
        end
      else
       value = ''
      end
    end
    if value.nil?
      add_to_sheet(@sheet_data[@curr.col][@curr.row])
      pop_value()
    else
      value.ljust(31)
    end
  end

  # Populate the "formula/contents" field with the cell's full value
  def pop_formula()
    value = @sheet_data[@curr.col][@curr.row]
    value.ljust(42)
  end

  # Get the Ruby Primitive value wrapped by a Model Primitive
  def inspect(object)
    # puts "Inspecting <#{object}> of type <#{object.class.name}>"
    namespace =  object.class.name[0..4]
    if namespace == 'Model'
      inspect(object.value)
    else
      if object.class.name == 'Array'
        "[#{inspect(object[0])}, #{inspect(object[1])}]"
      else
        object.to_s
      end
    end
  end

  # Highlight the cell according to the current location
  def highlight_current_cell
    y = (10 * @curr.col) + 9
    x = (2 * @curr.row) + 4

    # Remove the previous content and insert reverse coloring text
    @grid_win.setpos(x, y)
    @grid_win.attron(Curses::A_REVERSE)
    @grid_win.addstr(pop(@curr.col, @curr.row))
    @grid_win.attroff(Curses::A_REVERSE)
  end

  # Start and handle the editor's main application loop
  def start_editor
    Curses.init_screen
    Curses.start_color
    Curses.curs_set(0) # Hide cursor

    begin
      setup_grid_window

      loop do
        # puts "refreshing in editor loop"
        refresh
        # puts "about to handle input"
        handle_input
        # puts "input handled"
      end
    end
  end

  private

  # Initialize the program's windows
  def setup_grid_window
    max_y, max_x = Curses.stdscr.maxy, Curses.stdscr.maxx
    grid_height = @rows * 2 + 4
    grid_width = @cols * 11 + 1
    win_x = (max_x - grid_width) / 2

    @grid_win = Curses::Window.new(grid_height, grid_width, 0, win_x)

    @form_win = Curses::Window.new(4, 65, grid_height, win_x)

    @display_win = Curses::Window.new(4, 47, grid_height, 65 + 20)

    @mappings_win = Curses::Window.new(4, grid_width, grid_height + 5, win_x + 8)

    @grid_win.setpos(0, 0)
    @form_win.keypad(true)
    @grid_win.keypad(true)
  end

  # Refresh/reload the complete graphical interface
  def refresh
    puts "\n----------- REFRESHING SHEET -----------"
    puts "Current Cells (runtime):"
    @runtime.cells.each_pair do |address, cell|
      puts "#{address} -- #{cell.to_s}"
    end
    @grid_win.clear
    @form_win.clear
    @display_win.clear
    @mappings_win.clear

    grid = "     XSHEET V0.9 - DEVELOPMENT                      MODE: #{@mode.upcase}ING CELL [#{@curr.col}, #{@curr.row}]
    ┌───┬─────────┬─────────┬─────────┬─────────┬───────────────────┬─────────┬─────────┬─────────┬─────────┐
    | * |    0    |    1    |    2    |    3    |    4    |    5    |    6    |    7    |    8    |    9    |
    ├──═╬═════════╬═════════╬═════════╬═════════╬═════════╬═════════╬═════════╬═════════╬═════════╬═════════┤
    | 0 ║#{pop(0,0)}|#{pop(1,0)}|#{pop(2,0)}|#{pop(3,0)}|#{pop(4,0)}|#{pop(5,0)}|#{pop(6,0)}|#{pop(7,0)}|#{pop(8,0)}|#{pop(9,0)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 1 ║#{pop(0,1)}|#{pop(1,1)}|#{pop(2,1)}|#{pop(3,1)}|#{pop(4,1)}|#{pop(5,1)}|#{pop(6,1)}|#{pop(7,1)}|#{pop(8,1)}|#{pop(9,1)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 2 ║#{pop(0,2)}|#{pop(1,2)}|#{pop(2,2)}|#{pop(3,2)}|#{pop(4,2)}|#{pop(5,2)}|#{pop(6,2)}|#{pop(7,2)}|#{pop(8,2)}|#{pop(9,2)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 3 ║#{pop(0,3)}|#{pop(1,3)}|#{pop(2,3)}|#{pop(3,3)}|#{pop(4,3)}|#{pop(5,3)}|#{pop(6,3)}|#{pop(7,3)}|#{pop(8,3)}|#{pop(9,3)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 4 ║#{pop(0,4)}|#{pop(1,4)}|#{pop(2,4)}|#{pop(3,4)}|#{pop(4,4)}|#{pop(5,4)}|#{pop(6,4)}|#{pop(7,4)}|#{pop(8,4)}|#{pop(9,4)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 5 ║#{pop(0,5)}|#{pop(1,5)}|#{pop(2,5)}|#{pop(3,5)}|#{pop(4,5)}|#{pop(5,5)}|#{pop(6,5)}|#{pop(7,5)}|#{pop(8,5)}|#{pop(9,5)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 6 ║#{pop(0,6)}|#{pop(1,6)}|#{pop(2,6)}|#{pop(3,6)}|#{pop(4,6)}|#{pop(5,6)}|#{pop(6,6)}|#{pop(7,6)}|#{pop(8,6)}|#{pop(9,6)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 7 ║#{pop(0,7)}|#{pop(1,7)}|#{pop(2,7)}|#{pop(3,7)}|#{pop(4,7)}|#{pop(5,7)}|#{pop(6,7)}|#{pop(7,7)}|#{pop(8,7)}|#{pop(9,7)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 8 ║#{pop(0,8)}|#{pop(1,8)}|#{pop(2,8)}|#{pop(3,8)}|#{pop(4,8)}|#{pop(5,8)}|#{pop(6,8)}|#{pop(7,8)}|#{pop(8,8)}|#{pop(9,8)}|
    ├───╬─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┼─────────┤
    | 9 ║#{pop(0,9)}|#{pop(1,9)}|#{pop(2,9)}|#{pop(3,9)}|#{pop(4,9)}|#{pop(5,9)}|#{pop(6,9)}|#{pop(7,9)}|#{pop(8,9)}|#{pop(9,9)}|
    └───┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┴─────────┘
    "

    @grid_win.addstr(grid)

    formula_editor = "
    ┌──────────────────────────────────────────────────────────┐
    | Cell Contents: #{pop_formula}|
    └──────────────────────────────────────────────────────────┘
    "

    @form_win.addstr(formula_editor)

    display = "
    ┌───────────────────────────────────────┐
    | Value: #{pop_value}|
    └───────────────────────────────────────┘
    "
    @display_win.addstr(display)

    enter_desc = " Toggle View / Select Cell   "
    exit_desc = " Go Back / Exit XSheet   "
    clear_desc = " Clear Cell   "
    reset_desc = " Reset Sheet   "

    @mappings_win.attron(Curses::A_REVERSE)
    @mappings_win.addstr("\nESC")
    @mappings_win.attroff(Curses::A_REVERSE)
    @mappings_win.addstr(exit_desc)

    @mappings_win.attron(Curses::A_REVERSE)
    @mappings_win.addstr("ENTER")
    @mappings_win.attroff(Curses::A_REVERSE)
    @mappings_win.addstr(enter_desc)

    @mappings_win.attron(Curses::A_REVERSE)
    @mappings_win.addstr("^R")
    @mappings_win.attroff(Curses::A_REVERSE)
    @mappings_win.addstr(reset_desc)

    @mappings_win.attron(Curses::A_REVERSE)
    @mappings_win.addstr("DEL")
    @mappings_win.attroff(Curses::A_REVERSE)
    @mappings_win.addstr(clear_desc)

    @grid_win.refresh
    @form_win.refresh
    @display_win.refresh
    @mappings_win.refresh

    # Highlight the currently selected cell
    highlight_current_cell()
  end

  # Return true if the program is in view mode
  def view_mode?
    @mode == 'view'
  end

  # Input handling for the overall program
  def handle_input
    puts "CURRENTLY AT CELL [#{@curr.col}, #{@curr.row}]"
    key = @grid_win.getch
    # puts "KEYCODE: #{key}"
    case key
    when 60490 # Del
      clear_cell()
    when 18 # Ctrl + R
      # Reset data within the sheet
      @runtime.reset()
      @sheet_data = Array.new(@rows) { Array.new(@cols, '') }
    when Curses::KEY_DOWN
      # Handle down arrow key
      if view_mode?
        @curr.row = (@curr.row == 9) ? 0 : @curr.row + 1
      end
    when Curses::KEY_UP
      # Handle up arrow key
      if view_mode?
        @curr.row = (@curr.row == 0) ? 9 : @curr.row - 1
      end
    when Curses::KEY_RIGHT
      # Handle right arrow key
      # puts "RIGHT ARROW - VIEW"
      if view_mode?
        @curr.col = (@curr.col == 9) ? 0 : @curr.col + 1
      end
    when Curses::KEY_LEFT
      # puts "LEFT ARROW - VIEW"
      # Handle left arrow key
      if view_mode?
        @curr.col = (@curr.col == 0) ? 9 : @curr.col - 1
      end
    when 10 # Enter key
      puts "----------- ENTERED EDIT MODE -----------"
      @mode == 'view' ? @mode = "edit" : @mode = 'view'
      # puts "Current Mode: #{@mode}"
      if @mode == 'edit'
        handle_edit
        Curses.curs_set(0)
      end
    when 27 # Escape key
      exit_editor
    end
    refresh
  end

  # Input handling for editing a cell
  def handle_edit
    refresh
    if @sheet_data[@curr.col][@curr.row].length < 1
      value = ''
      value_index = 0
      cursor_pos = 21 # Adjusted cursor position
    else
      value = @sheet_data[@curr.col][@curr.row]
      value_index = value.length
      cursor_pos = 21 + value.length  # Adjusted cursor position
    end
    @form_win.setpos(2, cursor_pos)
    Curses.curs_set(1)
    refresh_form

    loop do
      # puts "@ index #{value_index} out of #{value.length}"
      left_value = (value_index != 0 ? value[0..value_index - 1] : '')
      right_value = value[value_index..42]
      key = @form_win.getch
      # puts "KEYCODE: #{key}"

      case key
      when Curses::KEY_LEFT
        # puts "LEFT ARROW - EDIT"
        cursor_pos != 21 ? cursor_pos -= 1 : cursor_pos = 21
        @form_win.setpos(2, cursor_pos)
      when Curses::KEY_RIGHT
        # puts "RIGHT ARROW - EDIT"
        value_index != value.length ? cursor_pos += 1 : cursor_pos = value.length + 21
        @form_win.setpos(2, cursor_pos)
      when 10 # Enter key
        begin
          if value.length > 0
            add_to_sheet(value)
          else
            clear_cell()
          end
        rescue RuntimeError => re
          puts re.message
        end
        @mode = 'view'
        break
      when 27 # Escape key
        @mode = 'view'
        break
      when 8 # Backspace
        value = "#{left_value.chop}#{right_value}"
        # puts "BACKSPACE - NEW VALUE IS #{value}"
        @form_win.setpos(2, 21)
        @form_win.addstr(value.ljust(42)) # Pad with whitespace and left-align
        @form_win.addstr("|")
        cursor_pos != 21 ? cursor_pos -= 1 : cursor_pos = 21
        @form_win.setpos(2, cursor_pos)
      else
        if (32 <= key.ord && key.ord <= 126)
          if value.length < 42
            value = "#{left_value}#{key.chr}#{right_value}"
            # puts "Length of Value is #{value.length}"
            @form_win.setpos(2, 21)
            @form_win.addstr(value.ljust(42)) # Pad with whitespace and left-align
            @form_win.addstr("|")
            cursor_pos += 1 # Move cursor position
            @form_win.setpos(2, cursor_pos)
          else
            @form_win.setpos(2, 21)
            @form_win.addstr(value.ljust(42)) # Pad with whitespace and left-align
            @form_win.addstr("|")
            @form_win.setpos(2, cursor_pos)
          end
        end
      end
      value_index = cursor_pos - 21
      refresh_form
    end
    puts "----------- EXITED EDIT MODE -----------"
  end

  # Refresh/reload the fromula window's graphical interface
  def refresh_form
    @form_win.refresh
  end

  # Add a value to the sheet at the current cell
  def add_to_sheet(value)
    add_to_sheet_at(value, @curr.col, @curr.row)
  end

  # Return whether or not a passed string is a valid numeric string
  def purely_numeric?(str)
    !!str.match(/^-?\d+(\.\d+)?$/) || !!str.match(/^-\.\d+$|^\d+\.$/) || !!str.match(/^\.\d+$|^-\d+\.$/)
  end

  # Add a value/cell to the sheet at the specified address
  def add_to_sheet_at(value, col, row)
    begin
      # Attempt to interpret the value
      if value[0] == '=' && (value.length > 1)
        final_value = interpret(value[1..value.length - 1])
      else
        # IF (                          (Numeric)                           XOR                           (Boolean)                            XOR                     (LValue)                      )
        if (((purely_numeric?(value.to_s)) && !(value.to_s.include?('to_'))) ^ ((value.to_s.upcase == 'TRUE') ^ (value.to_s.upcase == 'FALSE')) ^ ((value.to_s[0] == '[') && (value.to_s[-1] == ']')))
          puts "[DEBUG] cell value will be treated as a non-String\n"
          final_value = interpret(value[0..value.length - 1])
        elsif value.length < 1
          clear_cell_at(col, row)
        else
          puts "[DEBUG] cell value will be treated as a String\n"
          # puts "value added as string = #{value}"
          final_value = Model::String.new(value.to_s, 0, value.to_s.length - 1)
        end
      end

      # Set the cell value
      cell(address(col, row), final_value)

      # Store the source string entered by the user in @sheet_data
      @sheet_data[col][row] = value

    rescue RuntimeError=> re
      @sheet_data[col][row] = value
      puts "Error adding cell: \n\t#{re.message}"
      if re.message[0..51] == "Attempting to access an undefined cell @ CellAddress"
        string_value = "Cell #{re.message[53..re.message.length - 1]} is undefined"
      else
        string_value = 'non-access error'
        puts re.message
      end
      cell(address(col, row), Model::String.new(string_value, 0, string_value.length - 1))

    rescue TypeError => te
      @sheet_data[col][row] = value
      puts "Error adding cell: \n\t#{te.message}"
      # Illegal operand - Passed: <Model::Bool> (must be Integer) @ index 5
      split_err_msg = te.message.split('@')

      type = split_err_msg[0].split('::')[1].split('>')[0]
      index_num = split_err_msg[1].split('x ')[1]
      target_type = split_err_msg[0].split('must be ')[1].split(')')[0]

      # puts "TEST-FORMAT: \n\t\t<#{type}> @ i=#{index_num} must be <#{target_type}>"\
      string_value = "<#{type}> @ i=#{index_num} != <#{target_type}>"
      cell(address(col, row), Model::String.new(string_value, 0, string_value.length - 1))

    rescue ZeroDivisionError => zde
      @sheet_data[col][row] = value
      puts "Error adding cell: \n\t#{zde.message}"

      split_err_msg = zde.message.split('@')
      index_num = split_err_msg[1].split('x ')[1]

      string_value = "Illegal Zero Division @ i=#{index_num}"
      cell(address(col, row), Model::String.new(string_value, 0, string_value.length - 1))

    rescue SyntaxError => se
      @sheet_data[col][row] = value
      puts "Error adding cell: \n\t#{se.message}"

      split_err_msg = se.message.split(' @ index ')
      index_num = split_err_msg[1]

      # Check type of syntax error returned
      if se.message[0..13] == "Expected token"
        expected_token = split_err_msg[0].split("of type ")[1]
        string_value = "Expected <#{expected_token}> @ i=#{index_num}"

      elsif se.message[0..7] == "Expected"
        index_num = se.message.split("@ index ")[1]
        string_value = "Invalid Syntax @ i=#{index_num}"

      elsif se.message[0..14] == "Invalid Syntax:"
        index_num = se.message.split("@ index ")[1]
        invalid_token = se.message.split("{")[1].split("}")[0]
        string_value = "Unrecognized Token <#{invalid_token}> @ i=#{index_num}"

      elsif se.message[0..0] == "!"
        source = se.message.split('<')[1].split(">")[0]
        # puts "SOURCE -> #{source}"
        if source.length > 9
          source = "#{source[0..10]}.."
        end
        string_value = "Invalid Source: <#{source}>"
      end


      cell(address(col, row), Model::String.new(string_value, 0, string_value.length - 1))
    end
  end

  def clear_cell_at(col, row)
    @sheet_data[col][row] = ''
    @runtime.remove_cell(address(col, row))
    puts "CLEARED CELL @ [#{col}, #{row}]"
    refresh
  end

  # Clear a cell from the sheet
  def clear_cell()
    clear_cell_at(@curr.col, @curr.row)
  end

  # Lex source string
  def lex(source)
    lexer = Interp::Lexer.new(source)
    lexer.lex
  end

  # Pass in source | Ex: "... + ..."
  # Return the constructed AST
  def interpret(source)
    lexed_tokens = lex(source)

    parser = Interp::Parser.new(lexed_tokens)
    tree = parser.parse()
    # puts "tree.i_start = <#{tree.i_start}>"
    tree
  end

  # Construct an address
  def address(x, y)
    x_primitive = Model::Integer.new(x, 0, 0)
    y_primitive = Model::Integer.new(y, 0, 0)
    Model::CellAddr.new([x_primitive, y_primitive])
  end

  # Set a cell in the grid
  def cell(addr, tree)
    @runtime.set_cell(addr, tree)
    addr_eval = [addr.value[0].value, addr.value[1].value].to_s
    puts "SET CELL @ ADDRESS #{addr_eval} TO \"#{@sheet_data[@curr.col][@curr.row]}\""
  end

  def exit_editor
    @grid_win.close
    @display_win.close
    @form_win.close
    @mappings_win.close
    exit
  end
end
