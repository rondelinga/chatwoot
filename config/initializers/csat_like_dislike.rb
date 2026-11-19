Rails.application.config.to_prepare do
  Api::V1::Widget::BaseController.prepend(Api::V1::Widget::CsatLikeDislikeHint)
end
