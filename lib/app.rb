require 'digest/md5'
require 'open-uri'
require 'net/http'
require 'time'
require 'htmlentities'
=begin
def colour(text, colour_code)
	"#{colour_code}#{text}\e[0m"
end
def green(text); colour(text, "\e[32m"); end
def red(text); colour(text, "\e[31m"); end
def yellow(text); colour(text, "\e[33m"); end
def blue(text); colour(text, "\e[34m"); end
=end

class AtomPost
	attr_accessor :title
	attr_accessor :content
	attr_accessor :date
	attr_accessor :author
	attr_accessor :addr
	attr_accessor :user
	attr_accessor :pass
	attr_accessor :type

	def initialize(addrs=nil)
		self.addr=addrs unless addrs.nil?
	end

	def down_url(entry_url)
		#STDERR.puts "scanning #{entry_url}"
		url=URI.parse(entry_url)
		Net::HTTP.start(url.host,url.port) {|http|
			req = Net::HTTP::Get.new(url.path)
			req.basic_auth user,pass  unless user.nil?
			response = http.request(req)
			doc=Hpricot(response.body)
			e=doc.at('//entry').at('link[@rel="down"]')
			return 	URI.parse(e[:href]).path unless e.nil? 
		}
	end

	def send
		raise StandardError.new('Missing Address') if addr.nil?
		#3: Detailed control
		url = URI.parse(addr)
		#STDERR.puts "sending to #{url}"
		req = Net::HTTP::Post.new(url.path)
		req.basic_auth user,pass  unless user.nil?

		req.body  = '<?xml version="1.0"?>'+"\n"
		req.body  +='<entry xmlns="http://www.w3.org/2005/Atom">'+"\n"
		req.body  +='<title>'+recode_text(title)+'</title>'+"\n"
		req.body  +='<id>'+Digest::MD5.hexdigest(title+content)+'</id>'+"\n"
		req.body  +='<updated>'+date.xmlschema+'</updated>'+"\n"
		req.body  +='<author><name>'+author+'</name></author>'+"\n"
		req.body  +='<content>'+recode_text(content)+'</content>'+"\n"
		req.body  +='<category label="'+type+'" term="'+type+'" />'+"\n" unless type.nil?
		req.body  +='</entry>'+"\n"

		req.set_content_type('application/atom+xml;type=entry')

#	STDERR.puts	red("Send \n #{req.body.size > 500 ? req.body[0..250]+'[...]'+req.body[-250..-1]: req.body}")

		res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
		case res
		when Net::HTTPSuccess, Net::HTTPRedirection
#			STDERR.puts green(res['location']) if res['location']
			res['location'] if res['location']
		else
			res.error!
		end
	end

	def recode_text(txt)
		return txt if txt.blank?
		m=Hpricot(txt)
		m.traverse_text{|t| t.content=force_decimal_entities(t.content) if t.content.match(/&[a-z][a-z0-9]+;/i)}
		m.to_html
	end
	HTMLENCODER=HTMLEntities.new
	def force_decimal_entities(txt)
		HTMLENCODER.encode(HTMLENCODER.decode(txt),:decimal)
	end
end
