#!/usr/bin/ruby
require 'open-uri'
require 'conf.rb'
require 'downloader.rb'
require 'document.rb'
require 'parser.rb'
require 'feedbooks.rb'

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
	print "URL : " if entry.nil? || entry==''
	entry=STDIN.readline.strip unless valid
end
conf=Conf.new('conf.yaml')
content=Downloader.download(url)
#puts content.size
doc=Parser.new(conf).parse(content)
puts doc.toc.to_yaml
doc.to_feedbooks(conf)
