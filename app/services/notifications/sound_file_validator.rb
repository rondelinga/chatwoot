require 'open3'

class Notifications::SoundFileValidator
  class Error < StandardError; end

  ALLOWED_CONTENT_TYPES = %w[
    audio/mpeg
    audio/mp3
    audio/wav
    audio/x-wav
    audio/wave
    audio/vnd.wave
    audio/ogg
    audio/x-ogg
    audio/vorbis
    audio/oga
    application/ogg
  ].freeze
  MAX_SIZE = 2.megabytes
  MAX_DURATION_SECONDS = 5

  pattr_initialize [:file!]

  def validate!
    raise Error, I18n.t('errors.notification_sounds.missing') if file.blank?
    raise Error, I18n.t('errors.notification_sounds.invalid_type') unless allowed_type?
    raise Error, I18n.t('errors.notification_sounds.too_large') if file.size > MAX_SIZE

    duration = duration_seconds
    return if duration.blank?
    raise Error, I18n.t('errors.notification_sounds.too_long') if duration > MAX_DURATION_SECONDS
  end

  private

  def allowed_type?
    types = [file.content_type, detected_content_type].compact.map(&:downcase)
    types.any? { |type| ALLOWED_CONTENT_TYPES.include?(type) }
  end

  def detected_content_type
    Marcel::MimeType.for(file.tempfile, name: file.original_filename, declared_type: file.content_type)
  rescue StandardError
    nil
  end

  def duration_seconds
    path = file.tempfile.path
    ffprobe_duration(path) || wav_duration(path)
  end

  def ffprobe_duration(path)
    stdout, status = Open3.capture2(
      'ffprobe', '-v', 'error', '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1', path
    )
    return unless status.success?

    value = stdout.to_f
    value if value.positive?
  rescue Errno::ENOENT, StandardError
    nil
  end

  def wav_duration(path)
    File.open(path, 'rb') do |io|
      header = io.read(12)
      return unless header&.start_with?('RIFF') && header.end_with?('WAVE')

      byte_rate = nil
      data_size = nil

      until io.eof?
        chunk_id = io.read(4)
        break if chunk_id.blank?

        chunk_size = io.read(4)&.unpack1('V')
        break if chunk_size.blank?

        if chunk_id == 'fmt '
          io.read(8)
          byte_rate = io.read(4)&.unpack1('V')
          remaining = chunk_size - 12
          io.read(remaining) if remaining.positive?
        elsif chunk_id == 'data'
          data_size = chunk_size
          break
        else
          io.seek(chunk_size, IO::SEEK_CUR)
        end
      end

      return unless byte_rate&.positive? && data_size

      data_size.to_f / byte_rate
    end
  rescue StandardError
    nil
  end
end
