require './html_parser'

def main
  # the uri we are fetching: 'oscars best director award' in wikipedia
  uri = "https://en.wikipedia.org/wiki/Academy_Award_for_Best_Directing"
  html_parser = HtmlParser.new(uri)
  # get the link whose text is 'Ang Lee'. case insensitive.
  puts html_parser.find_href('Ang Lee')
  # get the link title whose text is 'Ang Lee'. case insensitive.
  puts html_parser.find_title('Ang Lee')
  # -------------------------------------
  # parse HTML table
  html_table_parser = HtmlTableParser.new(uri)
  html_table_parser.cell('year', '2014', 'winner film') { |x| puts x }
  
end

main