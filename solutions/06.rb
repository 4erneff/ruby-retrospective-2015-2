module TurtleGraphics
  class Turtle
    attr_accessor :width, :height, :table, :position

    def initialize(height, width)
      @width, @height = width, height
      @table, @position, @direction = [], [0, 0], 0
      @moves = [[0, 1], [1, 0], [0, -1], [-1, 0]]
      row = []
      (1..width).each { row << 0 }
      (1..height).each { @table << row.clone }
      @table[0][0] = 1
    end

    def draw(tool = nil, &block)
      if block_given?
        self.instance_eval &block
      end
      if tool.class == TurtleGraphics::Canvas::ASCII
        tool.format @table
      elsif tool.class == TurtleGraphics::Canvas::HTML
        tool.format_table @table
      else
        @table
      end
    end

    def move
      @position[0] = @position[0] + @moves[@direction][0]
      @position[1] = @position[1] + @moves[@direction][1]
      @position[0] = 0 if position[0] == @height
      @position[0] = (@height - 1) if position[0] < 0
      @position[1] = 0 if position[1] == @width
      @position[1] = (@width - 1) if position[1] < 0
      @table[@position[0]][@position[1]] += 1
    end

    def turn_left
      @direction -= 1
      @direction = 3 if @direction < 0
    end

    def turn_right
      @direction += 1
      @direction = 0 if @direction > 3
    end

    def look(orientation)
      orientation_map = { left: 2, up: 3, right: 0, down: 1 }
      @direction = orientation_map[orientation]
    end


    def spawn_at(row, column)
      @table[0][0] = 0
      @table[row][column] = 1
      @position = [row, column]
    end

  end

  module Canvas
    class ASCII
      attr_accessor :symbols

      def initialize(symbols)
        @symbols = symbols
      end

      def format(matrix)
        pick = get_pick(matrix)
        matrix.map { |row| format_row(row, pick) }.join("\n")
      end

      def format_row(row, pick)
        format_rule = -> (element) do
          intence = element.to_f / pick.to_f
          interval = 1.0 / (@symbols.size - 1).to_f
          index = 0
          while interval * index < intence do index += 1 end
          intence != 1.0 ? @symbols[index] : @symbols[-1]
        end
        row.map { |cell| format_rule.call cell }.join("")
      end

      def get_pick(matrix)
        matrix.max_by { |element| element.max }.max
      end
    end

    class HTML

      def initialize(size)
        @size = size
      end

      def format_table(matrix)
        pick = get_pick(matrix)
        style = get_style()
        table = get_table(matrix, pick)
        head = "<!DOCTYPE html>\n<html>\n<head>\n"
        style = "\t<title>Turtle graphics</title>\n\n\t" + style + "</head>\n"
        body = "<body>\n" + table + "</body>\n</html>\t"
        html = head + style + body
      end

      def get_pick(matrix)
        matrix.max_by { |element| element.max }.max
      end

      def get_style
        table = "\t\ttable {\n\t\t\tborder-spacing: 0;\n\t\t}\n"
        table_row = "\t\ttr {\n\t\t\tpadding: 0;\n\t\t}\n"
        size = "\t\t\twidth: #{@size}px;\n\t\t\theight: #{@size}px;\n"
        color = "\t\t\tbackground-color: black;\n\t\t\tpadding: 0;\n"
        cell = "\t\ttd {\n" + size + color + "\t\t}\n"
        style = "\t<style>\n" + table + table_row + cell + "\t</style>\n"
      end

      def format_row(row, pick)
        format_rule = -> (steps) do
          intensity = steps.to_f / pick.to_f
          opacity = format('%.2f', intensity)
          cell = "\t\t\t<td style=\"opacity: #{opacity}\"></td>\n"
        end
        row_body =  row.map { |cell| format_rule.call cell }.join("")
        "\t\t<tr>\n" + row_body + "\t\t</tr>\n"
      end

      def get_table(matrix, pick)
        table_body = matrix.map { |row| format_row(row, pick) }.join("")
        "\t<table>\n" + table_body + "\t</table>\n"
      end

    end

  end
end
