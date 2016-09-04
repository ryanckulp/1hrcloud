class SoundcloudController < ApplicationController
  before_action :authenticate_user!

  def connect
    redirect_to "https://soundcloud.com/connect?client_id=#{ENV['SOUNDCLOUD_CLIENT_ID']}&redirect_uri=#{ENV['SOUNDCLOUD_REDIRECT_URI']}&response_type=code"
  end

  def auth
    code = params['code']

    auth_params = {
      client_id: ENV['SOUNDCLOUD_CLIENT_ID'],
      client_secret: ENV['SOUNDCLOUD_CLIENT_SECRET'],
      grant_type: 'authorization_code',
      redirect_uri: ENV['SOUNDCLOUD_REDIRECT_URI'],
      scope: 'non-expiring',
      code: code
    }

    response = Curl.post("https://api.soundcloud.com/oauth2/token", auth_params)
    data = JSON.parse(response.body)

    current_user.access_token = data['access_token']
    current_user.refresh_token = data['refresh_token']
    current_user.code = code
    current_user.save
  end

end
