class User < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable
  validates_presence_of :email

  def soundcloud_profile
    SoundcloudService.me(self)
  end

  def playlists
    SoundcloudService.my_playlists(self)
  end

end
