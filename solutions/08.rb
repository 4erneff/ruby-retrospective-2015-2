class Spreadsheet

  class Error < StandardError
    def initialize(message)
      super
    end
  end

  attr_accessor :table

  def initialize(text = nil)
    if text == nil
      @table = []
    else
      @table = fetch_table(text)
    end
  end

  def empty?
    @table == []
  end

  def cell_at(string)
    index = TableIndex.new string
    row, column = index.integer_indexes[0],  index.integer_indexes[1]
    begin
      @table[row][column]
    rescue StandardError
      raise Error, "Cell '#{string}' does not exist"
    end
  end

  def [](string)
    result = self.calculate(string).to_s
    number = result.match(/\A([0-9.]+)\Z/)
    return result if number == nil or cell_at(string).match(/\A=/) == nil
    return number[1].to_i.to_s if number[1].to_i == Float(number[1])
    "%.2f" % number[1]
  end

  def calculate(string)
    cell = cell_at(string)
    if cell[0] == '='
      formula_cell cell
    else
      cell
    end
  end

  def to_s
    table = @table.map.with_index do |row, i|
      row.map.with_index { |cell, j| self[TableIndex.get_string_index(i, j)]}
    end
    table = table.map { |row| row.join("\t") }
    table.join("\n")

  end

  class TableIndex
    attr_accessor :integer_indexes
    def initialize(string)
      @table_indexes = fetch_indexes(string)
      @integer_indexes = get_integer_indexes
    end

    def get_integer_indexes
      indexes = @table_indexes
      column = integer_column_index indexes[0]
      row = indexes[1].to_i
      [row - 1, column - 1]
    end

    def integer_column_index(string)
      offset = 'A'.ord - 1
      string.chars.inject(0){ |x,c| x * 26 + c.ord - offset }
    end

    def fetch_indexes(string)
      match = string.match(/\A([A-Z]+)([1-9][0-9]*)\Z/)
      if match != nil
        [match[1], match[2]]
      else
       raise Spreadsheet::Error, "Ivalid cell index '#{string}'"
      end
    end

    def self.get_string_index(x, y)
      x = x + 1
      hash = Hash.new { |hash,key| hash[key] = hash[key - 1].next }
      hash = hash.merge({0 => "A"})
      hash[y] + x.to_s
    end
  end

  class Formula
    FORMULAS = ["ADD", "MULTIPLY", "SUBTRACT", "DIVIDE", "MOD"]
    LESS = "Wrong number of arguments for 'FOO': expected at least %s, got $s"
    WRONG = "Wrong number of arguments for 'FOO': expected %s, got %s"
    FLOAT_FORMAT = "%.2f"

    def initialize(table, string)
      @table = table
      @string = string
    end

    def evaluate
      formula = @string.match(/\A([A-Z]+)\([0-9A-Z.]+(, [0-9A-Z.]+)*\)\Z/)
      raise Error, "Invalid expression '#{@string}'" if formula == nil
      unless FORMULAS.include? formula[1]
        raise Error, "Unknown function '#{formula[1]}'"
      else
        self.send formula[1].downcase.to_sym
      end
    end

    def fetch_arguments
      formula = @string.match(/\([0-9A-Z.]+(, [0-9A-Z.]+)*\)\Z/)
      arguments = formula[0][1..-2].split(',').map(&:strip)
      arguments = arguments.map do |argument|
        if argument.match(/[A-Z]/) != nil
          Float(@table.calculate(argument))
        else
          Float(argument)
        end
      end
    end

    def add
      arguments = fetch_arguments
      raise Error, LESS % [2, arguments.size] if arguments.size < 2
      answer = arguments.inject(:+)
    end

    def multiply
      arguments = fetch_arguments
      raise Error, LESS % [2, arguments.size] if arguments.size < 2
      answer = arguments.inject(:*)
    end

    def subtract
      arguments = fetch_arguments
      raise Error, WRONG % [2, arguments.size] if arguments.size != 2
      answer = arguments[0] - arguments[1]
    end

    def divide
      arguments = fetch_arguments
      raise Error, WRONG % [2, arguments.size] if arguments.size != 2
      answer = arguments[0] / arguments[1]
    end

    def mod
      arguments = fetch_arguments
      raise Error, WRONG % [2, arguments.size] if arguments.size != 2
      answer = arguments[0] % arguments[1]
    end
  end

  private

  def fetch_table(text)
    table = []
    rows = text.split("\n")
    rows = rows.map { |e| e.strip }.select { |e| e != "" }
    rows.each { |row| table << row.split(/ {2,}|\t/).map(&:strip) }
    table
  end

  def formula_cell(cell)
    number = cell.match(/= *([0-9.]+)\Z/)
    return number[1] if number != nil
    is_reference = cell.match(/\A=([A-Z]+)([1-9][0-9]*)\Z/)
    return self[is_reference[0][1 .. -1]] if is_reference != nil
    Formula.new(self, cell[1..-1]).evaluate
  end

end
