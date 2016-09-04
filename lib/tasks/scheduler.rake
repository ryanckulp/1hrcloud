task :update_playlist => :environment do
  SoundcloudService.generate_playlist
  user = User.find(1)
  puts "Playlist updated!"
  puts "new access token: #{user.access_token}"
  puts "new refresh token: #{user.refresh_token}"
end
