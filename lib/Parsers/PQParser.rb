$lib = File.expand_path('../', File.dirname(__FILE__))

require "Parsers/Parser"
require 'Models/Paragraph'

class PQParser < Parser
    attr_accessor :nextParser
    def parse(paragraph)
        if paragraph.type == 'PQ'
            result = ""
            paragraph.text.each_line do |p|
                result += "> #{p}"
            end
            result
        else
            if !nextParser.nil?
                nextParser.parse(paragraph)
            end
        end
    end
end
