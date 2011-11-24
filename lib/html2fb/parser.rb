require 'hpricot'
require 'html2fb/document.rb'
require 'progressbar'
#require 'ruby-prof'
#require 'term/ansicolor'
#include Term::ANSIColor

module HTML2FB
	class Parser

		def initialize(conf)
			@conf=conf
		end

		def parse(txt)
			puts "Parsing HTML"
			pdoc=Hpricot(txt)
			if @conf['conv']
				mc=pdoc/'meta[@http-equiv="Content-Type"]'
				if mc.size>0
					charset=mc.first.attributes['content'].split(';').find do |s|
						s.strip[0,7]=='charset'
					end
					unless charset.nil?
						tc=charset.split('=').last.strip
					end

					unless tc.nil? 
						puts "Trying to convert source encoding from #{tc} to utf-8"
						require 'iconv'
						pdoc=Hpricot(Iconv.conv('utf-8',tc.downcase,txt))

					end

				end
			end
			doc=Document.new
			puts "Removing garbage elements"
			remove_objs(pdoc)
			ti=pdoc.at('title')
			doc.title= ti.extract_text.strip unless ti.nil?
			#			pdoc.search('//h3').each do |e|
			#				doc.content.push(e.inner_text)
			#			end

			puts "Building TOC"
			parse_text(pdoc,doc)	

			#			puts green(bold(doc.pretty_inspect))

			return doc
		end
		protected

		def remove_objs(doc)
			if @conf['remove'] then
				@conf['remove']['class'].each do |cl|
					doc.search('.'+cl).remove
				end unless @conf['remove']['class'].nil?
				@conf['remove']['expr'].each do |cl|
					doc.search(cl).remove
				end unless @conf['remove']['expr'].nil?
				@conf['remove']['before'].each do |cl|
					x=doc.at(cl)
					if x
						x.preceding.remove
						x.parent.children.delete(x)
					end
				end unless @conf['remove']['before'].nil?
				@conf['remove']['between'].each do |cl|
					#					puts "between "+cl.inspect
					t=doc.between(cl.first,cl.last)
					t.remove unless t.nil?
				end unless @conf['remove']['between'].nil?
				@conf['remove']['after'].each do |cl|
					x=doc.at(cl)
					if x
						x.following.remove
						x.parent.children.delete(x)
					end
				end unless @conf['remove']['after'].nil?
			end
			#			File.open('/tmp/test.html','w'){|f| f.write doc.to_html}
		end

		def parse_text(doc,ret)
			#			RubyProf.start


			aut=build_autom(@conf['select'],ret)

			pbar = ProgressBar.new("Parsing", doc.search('//').size)
			doc.traverse_all_element do |el|
				aut.feed(el)
				pbar.inc
			end
			pbar.finish
			aut.finish(doc)
=begin
			 result = RubyProf.stop
			  printer = RubyProf::FlatPrinter.new(result)
			  printer.print(STDOUT, 0)
			  printer.print(File.new('/versatile/prof','w'),0)
			    printer = RubyProf::GraphHtmlPrinter.new(result)
			      printer.print(File.new('/versatile/profgraph.html','w'), :min_percent=>0)
			    printer = RubyProf::CallTreePrinter.new(result)
			      printer.print(File.new('/versatile/profgraph.tree','w'), :min_percent=>0)
=end
		end

		protected

		def build_autom(conf_tab,doc)
			mach=StateMachine.new
			build_rec(mach,conf_tab)
			mach.reset(doc)
			mach
		end

		def build_rec(mach,conf_tab)
			return if conf_tab.size < 1
			exprs=conf_tab.collect{|e| e.reject{|k,v| k=='select'} }
			mach.add_level(exprs)
			build_rec(mach,conf_tab.collect{|e| e['select'] }.flatten.reject{|a|a.nil?})
		end
	end

	class StateMachine

		def initialize
			@levels=[]
			@current_level=0
			@starts=[]
			@done=[]
			@max_level=0
			@content=nil
		end

		def add_level(tab)
			tab=[tab] unless tab.is_a?Array
			@levels.push tab
			@current_level+=1
		end

		def reset(doc)
			@current_level=0
			@max_level=@levels.size
			@starts[0]=doc
			@content='body'
		end

		def inspect
			@levels.inspect+"\n"+@current_level.to_s+"\n\n"+@done.inspect
		end

		def create_fbsection(title,fblevel)
			s=Section.new
			s.fblevel=fblevel
			s.title = title
			s
		end

		def create_textNode(txt)
			Text.new(txt)
		end

		def finish(doc)
			unless @content.nil?
				#	t=create_textNode(doc.root.search(@content...doc.children.last.xpath))
				t=create_textNode(doc.at(@content).following.to_html)
				@starts[@current_level].content.push(t)
			end
			(1..@max_level).to_a.reverse.each do |l|
				close_section(l)
			end
			@starts[0]
		end

		def open_section(obj,lvl,el)
			if @content=='body'
				tmp=el.preceding[0..-1]
			else
				tmp=el.root.search(@content...(el.xpath))[1..-1]
			end
			if tmp.blank? #search can'find between siblins
				tmp=el.root.deep_between(@content,(el.xpath))
			end
			unless tmp.blank?
				tmph=tmp.to_html
				unless tmph.blank?
					t=create_textNode(tmph)
					@starts[@current_level].content.push(t)
				end
			end
			(lvl..@max_level).to_a.reverse.each do |l|
				close_section(l)
			end
			@starts[lvl]=create_fbsection(el.root.at(obj[:xpath]).extract_text,obj[:fblevel])
			@content=obj[:xpath]
			@current_level=lvl
		end

		def close_section(lvl)
			return if @starts[lvl].nil?
			llvl=lvl-1
			llvl=llvl-1 until !@starts[llvl].nil?
			@starts[llvl].content.push @starts[lvl]
			@starts[lvl]=nil
		end

		def feed(el)
			return if el.is_a?Hpricot::Text
			@done=[[]*@levels.size]

			@levels.each_with_index do  |lvl,i|
				lvl.each do |expr|
					#puts i.to_s+" "+el.inspect if el.in_search?(expr['expr'])
					if el.in_search?(expr['expr'])


						open_section({:xpath => el.xpath, :fblevel => expr['fblevel']},i+1,el)
						break
					end
				end
			end

		end
	end
end


class String
	def blank?
		self !~ /\S/
	end
end

class NilClass
	def blank?
		true
	end
end

module Hpricot::Traverse
	def in_search?(expr)
		if expr !~ /[^a-z0-9]/
			return self.name.downcase()==expr.downcase()	
		end

		se_in=self.parent
		if expr[0..1]=='/'
			se_in=self.root
		end
		se_in.search(expr).each do |el|
			return true if el==self
		end
		#		puts self.name+" "+expr
		return false
	end

	def root
		return @root unless @root.nil?
		se_in=self
		se_in=se_in.parent until se_in.parent.nil?
		@root=se_in
		se_in
	end

	def between(a,b)
		root.search(a..b)
	end

	def extract_text
		t=''
		self.traverse_all_element do |e|
			t+=e.content.to_s if e.is_a?(Hpricot::Text)
		end
		t
	end
	def deep_between(i,j)

		unless j.nil? || self.at(j).nil?
			tm=self.at(i)
			prec=tm.deep_preceding
			r=Hpricot::Elements[*self.at(j).deep_preceding.find_all{|el| !(prec.include?el || el==tm)}]
		else
			r=self.at(i).deep_following unless self.at(i).nil?
		end
		Hpricot::Elements[*select_end(r,i)]
	end

	def select_end(tab,expr)

		s=[]
		f=false
		idx=-1
		i=0
		tab.each do |e|
			if e.search(expr.gsub(e.xpath,'.')).size > 0
				idx=i
				#if e.search(i).size > 0
				if e.children.find{|ee| ee.xpath==expr }
					e.children.each do |ee|
						s << ee if f
						f=true if ee.xpath==expr
					end
				else
					s=select_end(e.children,expr)
				end
				break
			else
				i+=1
			end
			break if idx>0
		end
		return s+tab[(idx+1)..-1]
	end

	def deep_preceding()
		ret=Hpricot::Elements[]
		ret+=parent.deep_preceding if respond_to?(:parent) && !parent.is_a?(Hpricot::Doc )
		ret+=preceding
		Hpricot::Elements[*ret]
	end
	def deep_following()
		ret=following
		ret+=parent.deep_following if respond_to?(:parent) && !parent.is_a?(Hpricot::Doc )
		Hpricot::Elements[*ret]
	end

end

class Hpricot::Elements
	alias_method :blank?, :empty?
end
