#!/usr/bin/ruby
require 'rubygems'
require 'optparse'
require 'open-uri'
require 'tmpdir'
require 'launchy'
require 'digest/md5'
require 'html2fb'

include HTML2FB

options = {}
options[:conf] = "conf.yaml"
options[:preview] = true
options[:conv] = true
OptionParser.new do |opts|
	opts.banner = "Usage: html2fb [options] URL"

	opts.on("-c", "--conf FILE", String,"Configuration file") do |f|
		options[:conf] = f
	end
	opts.on("-s", "-s","Send to feedbooks") do |f|
		options[:preview] = !f
	end
	opts.on("-nc", "--no-conv","No charset conversion") do |f|
		options[:conv] = !f
	end
	opts.on("-C", "--cache", String,"Configuration file") do |f|
		options[:cache] = !f
	end
end.parse!
valid=false
entry=ARGV[0]
basedir=Dir.tmpdir+'/'
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
conf=Conf.new(options[:conf],options[:conv])
abridged_conf=conf.to_h.reject{|k,v| k=='fb'}
content=Downloader.download(url)
cache={}
ok=false
if options[:cache] && File.exists?(basedir+'.cache')
	cache=Marshal.restore(File.open(basedir+'.cache','r'))
	ok=Digest::MD5.hexdigest(content)==Digest::MD5.hexdigest(cache[:content])
	abridged_conf.each do |k,v|
		#		puts (abridged_conf[k]==cache[:conf][k]).inspect
		#		puts (abridged_conf[k]).inspect
		#		puts (cache[:conf][k]).inspect
		#		puts "-_-_-_-_"
		ok&&=abridged_conf[k]==cache[:conf][k]
	end
end
#puts content.size
if options[:cache] && ok
	puts "Using cache file"
	doc=cache[:doc]
else
	doc=Parser.new(conf).parse(content)
end

File.open(basedir+'.cache','w') do |e|
	Marshal.dump({:url => url,:conf => abridged_conf, :content => content, :doc => doc},e)
end
puts "Writing cache File "

puts doc.toc.to_yaml
if options[:preview]
	page=File.join(Dir.tmpdir(),Digest::MD5.hexdigest(url.to_s))+'.html'
	f=File.open(page,'w')
	f.write doc.to_html
	f.close
	puts "A preview of the parsed file should be opening in your webbrowser now"
	puts "If nothing open you can open the file located at : #{page}"
	puts "When happy with the parsed output rerun with -s option to send to Feedbooks.com"
	Launchy::Browser.run(page)
else
	doc.to_feedbooks(conf)
end
