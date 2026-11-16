# Who is on the guest list, who signed in, who tried to, and what they searched.
class AdminController < ApplicationController
  before_action { head :not_found unless Current.user.admin? }

  def show
    @guests = Guest.order(created_at: :asc)
    @users = User.order(last_seen_at: :desc)
    @search_counts = SearchRequest.collection.aggregate([ { "$group" => { "_id" => "$user_id", "count" => { "$sum" => 1 } } } ])
      .to_h { |row| [ row["_id"], row["count"] ] }
    @sign_in_requests = SignInRequest.order(created_at: :desc).limit(50)
    @search_requests = SearchRequest.order(created_at: :desc).limit(100).includes(:user, :search)
  end
end
