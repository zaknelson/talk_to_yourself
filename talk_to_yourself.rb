#! /usr/bin/ruby

require "rubygems"
require "mail"
require "xmlsimple"
require "zlib"
require "json"

class NgramEntry
	attr_accessor :children
	attr_accessor :parent
	attr_accessor :word
	attr_accessor :count

	def to_s 
		words = []
		current_ngram = self
		while current_ngram
			words.push current_ngram.word
			current_ngram = current_ngram.parent
		end
		words.reverse!
		"  #{words.join(' ')} : #{@count}"
	end

end

class TalkToYourself
	attr_accessor :chat_archive_dir
	attr_accessor :max_chats
	attr_accessor :max_results
	attr_accessor :conversers
	attr_accessor :ngram_depth
	attr_accessor :serialized_file_name

	def parse_mail(mail)
		mail.parts.map do |mail_parts|
			decoded_part = mail_parts.body.decoded
			begin
				data = XmlSimple.xml_in(decoded_part)
			rescue
				# Do nothing, the .eml comes in with non-xml parts that we ignore
				next
			end
				
			data["message"].each do |message|
				next if not message["body"]

				body = message["body"][0]
				from = message["from"]
				to = message["to"]

				next if not body.is_a?(String)
				next if not @conversers.include? from

				if not @name_ngram_entry_hash[from]
					@name_ngram_entry_hash[from] = {}
				end

				previous_word_queue = []
				body.split(" ").each do |word|
					word.downcase!
					word = word.gsub(/[^a-z ]/i, "")

					#ignore links for now, maybe something interesting to be done here?
					if word.include?("http") or word.empty?
						previous_word = nil
						previous_previous_word = nil
						next
					end

					previous_word_queue.shift if previous_word_queue.size == @ngram_depth
					previous_word_queue.push word

					ngram_entries_hash = @name_ngram_entry_hash[from]
					parentNgramEntry = nil
					previous_word_queue.each do |word|
						ngramEntry = ngram_entries_hash[word]
						if not ngramEntry
							ngramEntry = NgramEntry.new
							ngramEntry.count = 1
							ngramEntry.word = word
							ngramEntry.children = {}
							ngramEntry.parent = parentNgramEntry
							ngram_entries_hash[word] = ngramEntry
						else 
							ngramEntry.count += 1
						end
						parentNgramEntry = ngramEntry
						ngram_entries_hash = ngramEntry.children
					end
				end	
			end
		end
	end

	def get_top_by_count(ngrams_entries_hash)
		ngrams_entries_hash = ngrams_entries_hash.sort_by do |ngrams_entry| ngrams_entry.count end
		ngrams_entries_hash.reverse[0..@max_results]
	end

	def get_ngrams_at_depth(ngram_entries_hash, depth)
		if depth == 1
			result = Array.new
			ngram_entries_hash.each do |word, ngram_entry|
				result.push ngram_entry
			end
			result
		else
			result = Array.new
			ngram_entries_hash.each do |word, ngram_entry|
				children_entries = get_ngrams_at_depth(ngram_entry.children, depth - 1)
				result.concat(children_entries)
			end
			result
		end
	end

	def print_ngrams depth
		@name_ngram_entry_hash.each do |name, ngram_entries_hash|
			puts "#{name}: top #{depth}-grams of #{ngram_entries_hash.size}"
			ngrams_entries_at_depth = get_ngrams_at_depth(ngram_entries_hash, depth)
			puts ngrams_entries_at_depth.size
			top_ngrams_at_depth = get_top_by_count(ngrams_entries_at_depth)
			top_ngrams_at_depth.each do |ngramEntry|
				puts ngramEntry
			end
		end
	end

	def run
		if not File.exists? serialized_file_name
			count = 0
			@name_ngram_entry_hash = {}
			Dir.glob("#{chat_archive_dir}/**/*.gz") do |gz_path|
	  			mail_string = Zlib::GzipReader.new(open(gz_path)).read
				mail = Mail.read_from_string(mail_string)
				parse_mail(mail)

				count += 1
				if (count % 100 == 0)
					puts "Processed #{count} conversations..."
				end

				if max_chats and count >= max_chats
					break
				end
	  		end
  			file = File.open(serialized_file_name, "w")
  			Marshal.dump(@name_ngram_entry_hash, file)
  			file.close
  		else
  			puts "Reading from serialized data"
  			file = File.open(serialized_file_name, "r")
  			puts "File opened"
  			@name_ngram_entry_hash = Marshal.load(file)
  			puts "File marshalled"
  			file.close
  		end
	end
end

if __FILE__ == $0
	app = TalkToYourself.new
	app.chat_archive_dir = "archived-chats"
	app.serialized_file_name = "serialized_data"
	app.max_chats = 500
	app.max_results = 20
	app.conversers = ["maxnelso@gmail.com", "zak.nelson@gmail.com"]
	app.ngram_depth = 5;
	app.run

	5.times do |i|
		app.print_ngrams i+1
	end
end