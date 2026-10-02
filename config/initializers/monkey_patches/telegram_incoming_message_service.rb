module TelegramIncomingMessageProjectMethods
  private

  def set_project_attribute_after_perform
    return unless @contact
    return unless @inbox&.channel

    prefix = project_prefix_from_bot_name(@inbox.channel.try(:bot_name))
    return if prefix.blank?

    @contact.custom_attributes ||= {}
    @contact.custom_attributes['project'] = prefix
    @contact.save!
  rescue StandardError => e
    Rails.logger.error "[TG PROJECT] ERROR: #{e.class} #{e.message}\n#{e.backtrace.first(5).join("\n")}"
  end

  def project_prefix_from_bot_name(bot_name)
    bot_name.to_s.delete_prefix('@').split('_').map { |part| part.gsub(/casino/i, '') }.reject(&:empty?).first
  end
end

Rails.application.config.to_prepare do
  unless Telegram::IncomingMessageService.method_defined?(:original_perform)
    Telegram::IncomingMessageService.class_eval do
      include TelegramIncomingMessageProjectMethods
      alias_method :original_perform, :perform

      def perform
        original_perform
        set_project_attribute_after_perform
      end
    end
  end
end
