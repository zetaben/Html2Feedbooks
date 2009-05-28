#!/usr/bin/ruby
require 'optparse'
require 'open-uri'
require 'conf.rb'
require 'downloader.rb'
require 'document.rb'
require 'parser.rb'
require 'feedbooks.rb'
require 'tmpdir'
require 'launchy'

include HTML2FB

options = {}
options[:conf] = "conf.yaml"
options[:preview] = true
OptionParser.new do |opts|
	opts.banner = "Usage: html2fb [options] URL"

	opts.on("-c", "--conf FILE", String,"Configuration file") do |f|
		options[:conf] = f
	end
	opts.on("-s", "-s","Send to feedbooks") do |f|
		options[:preview] = !f
	end
end.parse!

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
conf=Conf.new(options[:conf])
content=Downloader.download(url)
#puts content.size
doc=Parser.new(conf).parse(content)
puts doc.toc.to_yaml
if options[:preview]
	page=File.join(Dir.tmpdir(),Digest::MD5.hexdigest(url.to_s))+'.html'
	f=File.open(page,'w')
	f.write doc.to_html
	f.close
	puts "A preview of the parsed file should be opening in your webbrowser now"
	puts "If nothing open you can open the file here : #{page}"
	puts "When happy with the parsed output rerun with -s option to send to Feedbooks.com"
	Launchy::Browser.run(page)
else
doc.to_feedbooks(conf)
end
