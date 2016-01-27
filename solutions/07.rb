module LazyMode
  class Date
    attr_accessor :year, :month, :day, :string_date

    def initialize(date)
      @year = date.split('-')[0].to_i
      @month = date.split('-')[1].to_i
      @day = date.split('-')[2].to_i
      @string_date = date
    end

    def <(date)
      return (@year < date.year) if @year != date.year
      return (@month < date.month) if @month != date.month
      return (@day < date.day) if @day != date.day
      return false
    end

    def next
      @day += 1
      @month += 1 if day > 30
      @year += 1 if @month > 12
      @day = 1 if day > 30
      @month = 1 if @month > 12
      string_repair
    end

    def string_repair
      day = "#{@day}"
      month = "#{@month}"
      year = get_year_formatted
      day = "0" + day if @day < 10
      month = "0" + month if @month < 10
      @string_date = year + "-" + month + "-" + day
    end

    def self.difference_in_days(date_one, date_two)
      days = date_two.day - date_one.day
      months = date_two.month - date_two.month
      years = date_two.year - date_one.year
      days + months * 30 + years * 12 * 30
    end

    alias :to_s :string_date
    private
    def get_year_formatted
      return @year.to_s if @year > 999
      return "0#{@year}" if @year > 99
      return "00#{@year}" if @year > 9
      return "000#{year}"
    end
  end

  class Period
    attr_accessor :date

    def initialize(string)
      @date = Date.new string.split(' ')[0]
      @interval = string.split(' ')[1]
      @count = @interval[1..-2].to_i if @interval != nil
    end

    def match(date)
      if @interval == nil
        date.to_s == @date.to_s
      else
        check_period date
      end
    end

    def check_period(date)
      return false if date < @date
      difference_in_days = LazyMode::Date.difference_in_days @date, date
      interval_in_days = get_interval_in_days
      difference_in_days % interval_in_days == 0
    end

    def get_interval_in_days
      if @interval[-1] == 'm'
        @count * 30
      elsif @interval[-1] == 'w'
        @count * 7
      else
        @count
      end
    end
  end

  class Note
    attr_accessor :header, :file_name, :tags, :notes, :scheduled_date

    def initialize(header, file_name, *tags)
      @header = header
      @file_name = file_name
      @tags = tags
      @body, @status, @scheduled_date = '', :topostpone, nil
      @notes = []
      @scheduled_date = nil
    end

    def scheduled(date)
      @scheduled_date = Period.new date
    end

    def status(status = nil)
      return @status if status == nil
      @status = status
    end

    def body(body = nil)
      return @body if body == nil
      @body = body
    end

    def note(note_header, *tags, &block)
      note = Note.new(note_header, @file_name, *tags)
      note.instance_eval &block
      notes << note
    end

    def get_main_note
      note = self.clone
      note.notes = []
      note
    end

    def get_inner_notes
      notes = []
      @notes.each do |note|
        notes << note.get_main_note
        notes = notes + note.get_inner_notes
      end
      notes
    end

    def date
      @scheduled_date.date
    end
  end

  class File
    attr_accessor :name, :notes

    def initialize(name)
      @name = name
      @notes = []
    end

    def note(note_header, *tags, &block)
      note = Note.new(note_header, @name, *tags)
      note.instance_eval &block
      notes << note
    end

    def get_notes
      notes = []
      @notes.each do |note|
        notes << note.get_main_note
        notes = notes + note.get_inner_notes
      end
      notes
    end

    def daily_agenda(date)
      notes = get_notes.select do |note|
        note.scheduled_date != nil and note.scheduled_date.match date
      end
      AgendaObject.new(date, notes)
    end

    def weekly_agenda(date)
      agenda = daily_agenda(date)
      6.times do
        date.next
        agenda.add daily_agenda(date)
      end
      agenda
    end

  end

  class AgendaObject
    attr_accessor :notes

    def initialize(date, notes)
      @notes = notes.clone
      return if date == nil
      @notes.each { |note| note.scheduled date.to_s }
    end

    def add(agenda)
      @notes = @notes + agenda.notes
    end

    def where(**filters)
      notes = @notes.clone
      notes = text_filter(notes, filters[:text]) if filters[:text] != nil
      notes = tag_filter(notes, filters[:tag]) if filters[:tag] != nil
      notes = status_filter(notes, filters[:status]) if filters[:status] != nil
      AgendaObject.new nil, notes
    end

    private
    def text_filter(notes, sample)
      notes.select { |note| note.header.match sample or note.body.match sample}
    end

    def tag_filter(notes, tag)
      notes.select { |note| note.tags.include? tag}
    end

    def status_filer(notes, status)
      notes.select { |note| note.status == status }
    end
  end

  module_function
  def create_file(file_name, &block)
    file = File.new file_name
    file.instance_eval &block
    file
  end
end
