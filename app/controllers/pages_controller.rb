class PagesController < ApplicationController

  def home
    @subscriber = Subscriber.new
  end

  def about
  end
end
