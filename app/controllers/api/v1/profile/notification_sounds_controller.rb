class Api::V1::Profile::NotificationSoundsController < Api::BaseController
  before_action :set_sound, only: :destroy

  def index
    @notification_sounds = current_user.notification_sounds.with_attached_file.order(created_at: :desc)
  end

  def create
    Notifications::SoundFileValidator.new(file: uploaded_file).validate!

    @notification_sound = current_user.notification_sounds.create!(
      filename: uploaded_file.original_filename.to_s,
      file: uploaded_file
    )
    render action: :create, status: :created
  rescue Notifications::SoundFileValidator::Error => e
    render_could_not_create_error(e.message)
  end

  def destroy
    @sound.destroy!
    head :ok
  end

  private

  def uploaded_file
    params.require(:file)
  end

  def set_sound
    @sound = current_user.notification_sounds.find(params[:id])
  end
end
