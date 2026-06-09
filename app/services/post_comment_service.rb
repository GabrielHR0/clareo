class PostCommentService
  ValidationError = Class.new(StandardError)

  def self.create(attrs)
    raise ValidationError, "post_id is required" unless attrs[:post_id]
    raise ValidationError, "content is required" unless attrs[:content] && !attrs[:content].strip.empty?

    attrs[:comment_id] ||= SecureRandom.uuid
    attrs[:author_id] ||= "00000000-0000-0000-0000-000000000000"
    attrs[:author_type] ||= "system"
    attrs[:author_name] ||= "Sistema"

    result = PostCommentsRepository.create(attrs)
    result.merge(
      content: attrs[:content],
      author_name: attrs[:author_name],
      author_id: attrs[:author_id]&.to_s,
      created_at: Time.now.utc
    )
  end

  def self.list(post_id, limit = 50)
    PostCommentsRepository.list(post_id, limit)
  end

  def self.delete(post_id, comment_id)
    PostCommentsRepository.delete(post_id, comment_id)
  end
end
