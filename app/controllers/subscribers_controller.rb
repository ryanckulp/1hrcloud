class SubscribersController < ApplicationController

  def create
    @subscriber = Subscriber.new(subscriber_params)

    if @subscriber.save
      flash[:notice] = "Great, you'll start getting new mixes tomorrow."
      redirect_to about_path
    else
      redirect_to root_path
    end
  end


  private

    def subscriber_params
      params.require(:subscriber).permit(:email)
    end

end
