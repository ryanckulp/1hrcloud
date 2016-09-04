class Playlist < ActiveRecord::Base
  belongs_to :user
  serialize :track_ids, Array
end
