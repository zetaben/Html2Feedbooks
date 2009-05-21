require 'app.rb'
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
					 e.to_feedbooks(conf)
			#		f << " \n " *  10
				end
			#end
		end
	end

	class Section
		@@level=0
		def to_feedbooks(conf)
			puts "Sending to feedbooks"
			fb=FBSession.session
			post=AtomPost.new "http://#{fb.host}/#{fb.booktype}/#{fb.bookid}/contents.atom"
			doc=Hpricot('<div xmlns:xhtml="http://www.w3.org/1999/xhtml">'+to_html+'</div>')
			doc.traverse_all_element do |e|
				unless e.is_a?Hpricot::Text 
					e.stag.name='xhtml:'+e.stag.name
					e.etag.name='xhtml:'+e.etag.name unless e.etag.nil?
				end
			end
			post.content=doc.to_html
			post.user=fb.user
			post.pass=fb.pass
			post.date=Time.now
			post.author=fb.user
			post.title=title
			post.send
		end

		alias :old_to_html :to_html

		def to_html
			ret=nil
			@@level+=1
			if @@level==1
				ret=old_to_html
			else
				ret="<h#{@@level+1}>"+title+"</h#{@@level+1}>"+old_to_html
			end
			@@level-=1
			ret
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
