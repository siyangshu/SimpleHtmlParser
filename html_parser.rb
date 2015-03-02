require 'rubygems'
require 'nokogiri' 
require 'open-uri'

class HtmlGetter
  # return Nokogiri::HTML::Document
  def HtmlGetter.get(uri)
    file_name = HtmlGetter.uri_to_file_name(uri)
    if Pathname.new(file_name).exist?
      file = open(file_name)
    else
      file = open(uri)
      file_out = File.open(file_name, 'w')
      file.to_a.each {|line| file_out.write(line)}
      file.seek(0, IO::SEEK_SET)
    end
    return Nokogiri::HTML(file)
  end
  
  def HtmlGetter.get_local(file_name)
    Nokogiri::HTML(open(file_name))
  end
  
  def HtmlGetter.uri_to_file_name(uri)
    # puts uri
    file_name = URI(uri).path
    file_name = file_name.gsub(/[\/:]/, '_')
    return file_name
  end
end

class HtmlParser
  attr_reader :data
  
  def initialize(uri)
    @uri = uri
    @uri_host = URI(uri).scheme + '://' + URI(uri).host
    @html_doc = HtmlGetter.get(uri)
    @data = nil
  end
  
  def data
    if !@data
      @data = {}
      result = @html_doc.xpath("//a[@href and @title]")
      result.each do |element|
        key_word = format element.xpath(".//text()").to_s
        href = element.xpath(".//@href").to_s
        if !URI(href).host
          href = (URI(@uri_host) + URI(href)).to_s
        end
        title = element.xpath(".//@title").to_s
        @data[key_word] = [href, title]
      end       
    end
    @data
  end
  
  def find_href(key_word)
    if data[format key_word]
      return data[format key_word][0]
    end
  end 

  def find_title(key_word)
    if data[format key_word]
      return data[format key_word][1]
    end
  end 
end

class HtmlTableParser
  
  def initialize(uri, data_width = nil)
    @uri = uri
    @html_doc = HtmlGetter.get(uri)
    @tables = nil
    @data_width = data_width
  end
  
  def tables
    if !@tables
      @tables = []
      xpath = "//table[not(descendant::table)]"
      @html_doc.xpath(xpath).each do |table|
        @tables.push Table.new(table, @data_width)
      end   
    end
    @tables
  end

  # head: text in <th> tag, e.g. column name
  # data: text in <td> tag, e.g. text in some cell
  # yield all elements in that row including 'data' 
  def row(head, data)
    tables.each do |table|
      table.row(head, data) {|x| yield x}
    end
  end

  # head: text in <th> tag, e.g. column name
  # yield all elements in that column
  def column(head)
    tables.each do |table|
      table.column(head) {|x| yield x}
    end    
  end

  # head, another_head: text in <th> tag, e.g. column name
  # data: text in <td> tag, e.g. text in some cell
  # same as the method 'row', however only yield the element in comlumn 'another_head'
  def cell(head, data, another_head)
    tables.each do |table|
      table.cell(head, data, another_head) {|x| yield x}
    end    
  end


  class Table
    attr_accessor :head
      
    def initialize(table_element, data_width = nil)
      @head = []
      table_element.xpath(".//tr/th").each do |a_head|
        @head.push format_head(a_head.xpath("./text()").to_s)
      end

      @data = []
      table_element.xpath(".//tr[child::td]").each do |row|
        a_row = []
        row.xpath("./td").each do |cell|
          a_row.push format(cell.xpath(".//text()").to_s)
        end
        @data.push a_row
      end
      
      remove_data_by_width data_width
    end
      
    def row(head, data)
      head = format_head head
      data = format data
      index = @head.index(head)
      if index
        @data.each do |entry|
          yield entry if entry[index].include? data
        end
      end
    end
    
    def column(head)
      head = format_head head
      index = @head.index(head)
      if index
        @data.each do |entry|
          yield entry[index]
        end
      end      
    end
    
    def cell(head, data, another_head)
      head = format_head head
      data = format data
      another_head = format_head another_head
      index = @head.index(head)
      another_index = @head.index(another_head)
      if index && another_index
        @data.each do |row|
          yield row[another_index] if row[index].include? data
        end
      end      
    end
    
    def remove_data_by_width data_width
      return if !data_width
      @data.select! { |x| x.length == data_width }
    end

    
  end
end

class WikiIntroParser
  def initialize(uri)
    @uri = uri
    @html_doc = HtmlGetter.get(uri)
    @data = nil
  end
  
  def data
    if !@data
      @data = {}
      result = @html_doc.xpath("//table[not(descendant::table)]")
      result.each do |table|
        table.xpath(".//tr").each do |entry|
          key_word = format entry.xpath(".//th//text()").to_s
          values = []
          # devided by <li>
          entry.xpath(".//td//li").each do |value|
            values.push format(value.xpath(".//text()").to_s)
          end
          # devided by <span>
          if values == []
            entry.xpath(".//td/span").each do |value|
              values.push format(value.xpath(".//text()").to_s)
            end
          end
          # devided by <br>
          if values == []
            entry.xpath(".//td//text()").each do |value|
              s = format(value.to_s)
              values.push s if s != ""
            end
          end
          @data[key_word] = values
        end
      end
    end
    @data
  end
  
  def intro type
    data[format type]
  end
end

def format string, remove_newline:false
  string.downcase!
  if remove_newline
    string.gsub!(/\n+/, " ")
  else
    string.gsub!(/\n+/, "\n")
  end
  string.gsub!(/ +/, " ")
  string.strip!
  string
end

def format_head string
  format string, remove_newline:true  
end


def retrieve(string, item_delimiter, type_delimiter, reserve_index)
  s = format string
  s = s.split(item_delimiter) if item_delimiter
  s.map! { |x| x.split(type_delimiter)[reserve_index] } if type_delimiter
  s.select! { |x| format(x) != "" }
  s
end
