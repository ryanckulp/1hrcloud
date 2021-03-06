class SoundcloudService

  # authentication
  CLIENT_ID = ENV['SOUNDCLOUD_CLIENT_ID']
  CLIENT_SECRET = ENV['SOUNDCLOUD_CLIENT_SECRET']
  APP_VERSION = ENV['SOUNDCLOUD_APP_VERSION'] # todo: investigate if needed

  # lookups
  BASE_URL = 'https://api.soundcloud.com'
  BASE_URL_PUT = 'https://api-v2.soundcloud.com'

  # endpoints
  USER_ENDPOINT = '/me'
  PLAYLISTS_ENDPOINT = '/playlists/'
  TRACKS_ENDPOINT = '/tracks/'

  # pointers
  PLAYLIST_ID = ENV['SOUNDCLOUD_PLAYLIST_ID']

  # filters
  NEGATIVE_TAGS = ['food', 'cook', 'how-to', 'learn', 'podcast']
  NEGATIVE_TITLES = ['liveset', 'festival']
  TIME_FORMULA = "%Y-%m-%d %H:%M:%S" # coerces Ruby datetime to soundcloud (yyyy-mm-dd hh:mm:ss)
  MINIMUM_PLAY_COUNT = ENV['SOUNDCLOUD_MINIMUM_PLAYS'].to_i
  MAXIMUM_BPM = ENV['SOUNDCLOUD_MAXIMUM_BPM'].to_i

  class << self

    def me(user)
      resp = Curl.get(BASE_URL + USER_ENDPOINT, {oauth_token: user.access_token})
      JSON.parse(resp.body)
    end

    def my_playlists(user)
      resp = Curl.get(BASE_URL + USER_ENDPOINT + PLAYLISTS_ENDPOINT, {oauth_token: user.access_token})
      playlists = JSON.parse(resp.body)
    end

    # sort tracks that have been around at least XX hours
    def created_at_filter(options)
      start_date = options[:from].minutes.ago
      end_date = options[:to].minutes.ago
      from = URI.encode(start_date.strftime(TIME_FORMULA))
      to = URI.encode(end_date.strftime(TIME_FORMULA))

      "created_at[from]=#{from}&created_at[to]=#{to}"
    end

    # 58 -> 62 mins; 3480000 ms -> 3840000 ms
    def duration_filter
      "duration[from]=3480000&duration[to]=3720000"
    end

    def generate_filters(options)
      created_at_timespan = created_at_filter(options)
      duration = duration_filter

      "#{duration}&filter=public&#{created_at_timespan}&limit=200"
    end

    def hot_tracks
      filters = generate_filters({from: 1800, to: 1680}) # past 28-30 hours
      resp = Curl.get(BASE_URL + TRACKS_ENDPOINT + "?client_id=#{CLIENT_ID}&#{filters}")
      tracks = JSON.parse(resp.body)

      # returns IDs of tracks that match secret sauce prefs
      tracks.map do |t|
        if t['playback_count'].present?

          if !!t['title']
            title_words = t['title'].split.map(&:downcase)
            next if title_words.any? {|word| NEGATIVE_TITLES.include?(word)} # ignore track if it matches negative keywords
          end

          # 1. is this track really music?
          if !!t['tag_list']
            tags = t['tag_list'].split.map(&:downcase) # sanitize all the tags to downcase
            next if tags.any? {|tag| NEGATIVE_TAGS.include?(tag)} # ignore track if it matches negative keywords
          end

          # 2. does this track have a ridiculous BPM?
          next if !!t['bpm'] && t['bpm'] > MAXIMUM_BPM

          # 3. skip tracks that are live recordings
          next if !!t['track_type'] && (t['track_type'] == 'recording' || t['track_type'] == 'live')

          # 4. ensure track has at least N plays
          t['id'] if t['playback_count'] > MINIMUM_PLAY_COUNT

        end
      end.compact
    end

    def get_playlist_tracks(playlist_id)
      resp = Curl.get(BASE_URL + PLAYLISTS_ENDPOINT + playlist_id.to_s + "?client_id=#{CLIENT_ID}")
      JSON.parse(resp.body)['tracks']
    end

    def refresh_access_token!
      u = User.find(1) # hard-coded admin user who owns the playlist
      refresh_token = u.refresh_token
      code = u.code

      auth_params = {
        client_id: ENV['SOUNDCLOUD_CLIENT_ID'],
        client_secret: ENV['SOUNDCLOUD_CLIENT_SECRET'],
        grant_type: 'refresh_token',
        redirect_uri: ENV['SOUNDCLOUD_REDIRECT_URI'],
        scope: 'non-expiring',
        code: code,
        refresh_token: refresh_token
      }

      response = Curl.post("https://api.soundcloud.com/oauth2/token", auth_params)
      data = JSON.parse(response.body)

      u.access_token = data['access_token']
      u.refresh_token = data['refresh_token']
      u.save
    end

    def get_access_token
      refresh_access_token!
      User.find(1).access_token
    end

    # concern/todo: even though we de-dupe, potential persist track_id order so that playlist links don't break?
    def generate_playlist
      previous_track_ids = get_playlist_tracks(PLAYLIST_ID).map {|t| t['id']}
      final_track_ids = (previous_track_ids + hot_tracks).uniq # remove duplicates

      auth = "?client_secret=#{CLIENT_SECRET}&client_id=#{CLIENT_ID}&app_version=#{APP_VERSION}" # app_version taken from network tab, console
      params = {playlist: {tracks: final_track_ids}}
      access_token = get_access_token

      # only update playlist if new hot tracks were found
      if previous_track_ids.uniq.sort != final_track_ids.uniq.sort
        Curl.put(BASE_URL_PUT + PLAYLISTS_ENDPOINT + PLAYLIST_ID + auth, params.to_json) do |http|
          http.headers['Origin'] = 'https://soundcloud.com'
          http.headers['Authorization'] = "OAuth #{access_token}"
        end

        playlist = Playlist.find_or_create_by(soundcloud_id: PLAYLIST_ID)
        playlist.track_ids = final_track_ids
        playlist.save
      end
    end

    def clear_playlist(user, playlist_id)
      track_ids = []

      auth = "?client_secret=#{CLIENT_SECRET}&client_id=#{CLIENT_ID}&app_version=#{APP_VERSION}" # app_version taken from network tab, console
      params = {playlist: {tracks: track_ids}}

      Curl.put(BASE_URL_PUT + PLAYLISTS_ENDPOINT + playlist_id.to_s + auth, params.to_json) do |http|
        http.headers['Origin'] = 'https://soundcloud.com'
        http.headers['Authorization'] = "OAuth #{user.access_token}"
      end
    end

  end
end
