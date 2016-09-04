task :update_playlist => :environment do
  SoundcloudService.generate_playlist
  puts "Playlist updated!"
end
