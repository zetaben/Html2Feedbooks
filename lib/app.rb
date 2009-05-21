require 'digest/md5'
require 'open-uri'
require 'net/http'
require 'time'
require 'htmlentities'

class AtomPost
	attr_accessor :title
	attr_accessor :content
	attr_accessor :date
	attr_accessor :author
	attr_accessor :addr
	attr_accessor :user
	attr_accessor :pass

	def initialize(addrs=nil)
		self.addr=addrs unless addrs.nil?
	end

	def send
		raise StandardError.new('Missing Address') if addr.nil?
		#3: Detailed control
		url = URI.parse(addr)
		req = Net::HTTP::Post.new(url.path)
		req.basic_auth user,pass  unless user.nil?

		req.body  = '<?xml version="1.0"?>'+"\n"
		req.body  +='<entry xmlns="http://www.w3.org/2005/Atom">'+"\n"
		req.body  +='<title>'+recode_text(title)+'</title>'+"\n"
		req.body  +='<id>'+Digest::MD5.hexdigest(title+content)+'</id>'+"\n"
		req.body  +='<updated>'+date.xmlschema+'</updated>'+"\n"
		req.body  +='<author><name>'+author+'</name></author>'+"\n"
		req.body  +='<content>'+recode_text(content)+'</content>'+"\n"
		req.body  +='</entry>'+"\n"

		req.set_content_type('application/atom+xml;type=entry')

		File.open('/tmp/test4.txt','w') do |f|
			f << req.body
		end

		res = Net::HTTP.new(url.host, url.port).start {|http| http.request(req) }
		case res
		when Net::HTTPSuccess, Net::HTTPRedirection
			# OK
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
