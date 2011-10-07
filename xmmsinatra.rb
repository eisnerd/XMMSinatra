#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'erb'
require 'xmmsclient'
require 'utils'
require 'uri'

configure(:development) do |c|
  require "sinatra/reloader"
  c.also_reload "utils.rb"
end

Conn = Xmms::Client.new('XMMSinatra').connect(ENV['XMMS_PATH'])

get '/' do
        erb :index
end 

get '/info' do
        content_type 'text/json'

        id = Conn.playback_current_id.wait.value

        if (!id)
                %({"id": "", "artist": "", "album": "", "title": ""})
        else
                info = Conn.medialib_get_info(id).wait.value.to_propdict
                if (!info[:title].nil?)
                        title = info[:title]
                else
                        title = info[:url]
                end
                %({"id": "#{info[:id]}", "artist": "#{info[:artist]}", "album": "#{info[:album]}", "title": "#{title}"})
        end
end

=begin 
#irb ad-hoc test code

	irb -r xmmsclient -r utils.rb -r uri

Conn = Xmms::Client.new('XMMSinatra').connect(ENV['XMMS_PATH'])		
pl = Conn.playlist.entries.wait.value.select(&:nonzero?).map{|id| Conn.medialib_get_info(id).wait.value.to_propdict}
pl.split_by_(proc {|i| i[:artist]}) {|i,j| puts i}
pl.split_by{|i| i[:artist]}
pl.split_by_(proc {|i| i[:album]}){|al,is| ar = nil; is.each{|i| if ar == nil; ar = i[:artist].split(/; | \/ /); else ar &= i[:artist].split(/; | \/ /); end}; ar}
pl.split_by_(proc {|i| i[:album]}){|al,is| ar = is.map{|i| i[:artist].split(/; | \/ /)}.common}
=end

		def album(i)
			i[:album]._?((path = URI.unescape(i[:url]).gsub('+',' ').path_components)[1..[path.length - 4, 1].max].reverse.join(": "))
		end
		def artists(i)
			i[:artist].split(/; | \/ /)
		end
		def title(i)
			i[:title]._? i[:url]
		end

get '/playlist' do
        content_type 'text/json'

        %({"albums": [) +
		Conn.playlist.entries.wait.value.
			select(&:nonzero?).map{|id| Conn.medialib_get_info(id).wait.value.to_propdict}.
			split_by {|i| album(i)}.map{|al,is|
				ar = is.common{|i| artists(i)}
				%({"album": "#{al}", "artist":"#{ar.join "; "}", "items":[) + (is.map{|i| 
					%({"id": "#{i[:id]}", "artist": "#{(artists(i) - ar).join "; "}", "album": "#{album i}", "title": "#{title i}"})
				}.join(", ")) + "]}"
			}.join(", ") + "]}"
end

get '/art/:id' do |id|
        content_type 'image/jpeg'

        info = Conn.medialib_get_info(id.to_i).wait.value.to_propdict

        if (info[:picture_front])
                Conn.bindata_retrieve(info[:picture_front]).wait.value
        else
                File.read('nocover.png')
        end
end

get '/search/:query' do |query|
        c = Xmms::Collection.parse(query)

        reply = Conn.coll_query_ids(c).wait.value

        if (reply.length > 0)
                Conn.playlist.clear.wait

                reply.each do |id|
                        if (id.zero?)
                                next
                        end
                        Conn.playlist.add_entry(id).wait
                end

                "OK"
        else
                "FAIL"
        end
end

get '/select/:id' do |id|
        Conn.playlist_set_next(id.to_i - 1).wait
        Conn.playback_tickle.wait
end

get '/playpause' do
        if (Conn.playback_status.wait.value == Xmms::Client::PLAY)
                Conn.playback_pause.wait
        else
                Conn.playback_start.wait
        end
end

get '/prev' do
        Conn.playlist_set_next_rel(-1).wait
        Conn.playback_tickle.wait
end

get '/next' do
        Conn.playlist_set_next_rel(1).wait
        Conn.playback_tickle.wait
end
