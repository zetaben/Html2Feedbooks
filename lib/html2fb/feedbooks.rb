require 'html2fb/app.rb'
require 'hpricot'
require 'digest/md5'

module HTML2FB

	class FBSession

		attr_accessor :bookid
		attr_accessor :booktype
		attr_accessor :user
		attr_accessor :pass
		attr_accessor :host
		@@fbsession=nil
		def initialize(conf)
			StandardError.new('Already in session') unless @@fbsession.nil?
			@@fbsession=self
			self.bookid=ask(conf['fb']['bookid'],"Book Id")
			self.booktype=ask(conf['fb']['booktype'],"Book Type")
			self.user=ask(conf['fb']['user'],"User")
			self.pass=ask(conf['fb']['pass'],"Pass")
			self.host=conf['fb']['host']
			self.host='feedbooks.com' if @host.nil?
		end

		def self.session
			return @@fbsession
		end

		def pass=(pas)

			if pas.gsub(/[^a-z0-9]/,'').size==32
				@pass=pas
			else
				@pass= Digest::MD5.hexdigest(pas)
			end
		end
	end


	class Document
		def to_feedbooks(conf)
			FBSession.new(conf)
			#File.open('/tmp/test3.html','w') do |f|
			content.each do |e|
				#		f << e.to_feedbooks(conf)
				e.to_feedbooks(conf,nil)
				#		f << " \n " *  10
			end
			#end
		end
	end

	class FBPost
		def self.push(conf,tit,cont,type,path=nil)
			puts "Sending to feedbooks #{tit} with type #{type}"
			fb=FBSession.session
			if path.nil?
				post=AtomPost.new "http://#{fb.host}/#{fb.booktype}/#{fb.bookid}/contents.atom"
			else
				post=AtomPost.new "http://#{fb.host}#{path}"
			end

			post.content=cont
			post.user=fb.user
			post.pass=fb.pass
			post.date=Time.now
			post.author=fb.user
			post.title=tit
			post.type=type
			s=post.send
			post.down_url(s) unless s.nil?
		end
	end

	class Section
		@@level=0
		@@types=['Part','Chapter','Section']
		def to_feedbooks(conf,path=nil)
			type=self.fblevel.to_s.downcase.strip.capitalize
			unless @@types.include?type
				type=@@types[@@level]||@@types[-1]
			end
			fbpath=FBPost.push(conf,title,'',type,path)
			@@level+=1
			content.each do |e|
				e.to_feedbooks(conf,fbpath)
			end
			@@level-=1
		end

		alias :old_to_html :to_html

		def to_html
			ret=nil
			ret="<h#{@@level+1}>"+title+"</h#{@@level+1}>"
			@@level+=1
			ret+=old_to_html
			@@level-=1
			ret
		end
	end

	class Text
		def to_feedbooks(conf,path=nil)
			stxt=to_html
			return unless stxt.strip.size > 0
			doc=Hpricot('<div xmlns:xhtml="http://www.w3.org/1999/xhtml">'+stxt+'</div>')
			doc.traverse_all_element do |e|
				unless e.is_a?Hpricot::Text 
					e.name='xhtml:'+e.name
					e.etag='xhtml:'+e.etag unless (!e.respond_to?:etag) || e.etag.nil?
				end
			end
			FBPost.push(conf,'',doc.to_html,"Text",path) 
		end
	end
end

def ask(txt,disp='Prompt')
	return txt unless txt.nil? || txt =='#ask#'
	begin
		txt=nil
		print disp+' : '
		txt=STDIN.readline.strip
	end while txt.nil? || txt.size==0
	txt
end
