#!/usr/bin/ruby
require 'rubygems'
require 'sinatra'
require 'erb'
require 'xmmsclient'

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

get '/playlist' do
        content_type 'text/json'

        body = %({"items": [)
        Conn.playlist.entries.wait.value.each_with_index do |id, index|
                if (id.zero?)
                        next
                end
                info = Conn.medialib_get_info(id).wait.value.to_propdict
                if (!index.zero?)
                        body += ','
                end
                if (!info[:title].nil?)
                        title = info[:title]
                else
                        title = info[:url]
                end
                body += %({"id": "#{info[:id]}", "artist": "#{info[:artist]}", "album": "#{info[:album]}", "title": "#{title}"})
        end

        body += ']}'
        body
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
