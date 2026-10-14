# Posts the like/dislike CSAT hint as the first message of every conversation
# the web widget starts. Prepended to Api::V1::Widget::BaseController in
# config/initializers/csat_like_dislike.rb so the upstream controller stays untouched.
module Api::V1::Widget::CsatLikeDislikeHint
  private

  def create_conversation
    conversation = super
    ::MessageTemplates::Template::CsatLikeDislikeHint.new(conversation: conversation).perform
    conversation
  end
end
