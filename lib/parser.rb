require 'hpricot'
require 'document.rb'
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
					doc.between(cl.first,cl.last).remove
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
			tmp=el.root.search(@content...(el.xpath))[1..-1]
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
			@starts[lvl-1].content.push @starts[lvl]
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

	def extract_text
		t=''
		self.traverse_all_element do |e|
			t+=e.content.to_s if e.is_a?(Hpricot::Text)
		end
		t
	end
end

class Hpricot::Elements
	alias_method :blank?, :empty?
end
