#!/usr/bin/ruby
require 'open-uri'
require 'lib/downloader.rb'
require 'lib/document.rb'
require 'lib/parser.rb'

include HTML2FB

valid=false
entry=ARGV[0]
while !valid
	url=nil
	begin
		url=Downloader.valid_url?(entry)
		valid=true
	rescue Exception => e 
		STDERR.puts 'Invalid URL' unless entry.nil? || entry==''
		valid=false
		puts e
	end
	print "URL : "
	entry=STDIN.readline.strip unless valid
end
content=Downloader.download(url)
puts content.size
doc=Parser.new.parse(content)
puts doc.toc.to_yaml
