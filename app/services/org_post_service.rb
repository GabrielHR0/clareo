class OrgPostService
  ValidationError = Class.new(StandardError)

  def self.create(attrs)
    raise ValidationError, "organization_id is required" unless attrs[:organization_id]
    raise ValidationError, "content is required" unless attrs[:content] && !attrs[:content].strip.empty?

    attrs[:post_id] ||= SecureRandom.uuid
    attrs[:author_id] ||= "00000000-0000-0000-0000-000000000000"
    attrs[:author_type] ||= "system"
    attrs[:author_name] ||= "Sistema"

    OrgPostsRepository.create(attrs)
  end

  def self.list_with_comments(org_id, limit = 50)
    posts = OrgPostsRepository.list(org_id, limit)
    posts.map do |post|
      comments = PostCommentsRepository.list(post[:post_id], 20)
      attachments = PostAttachmentsRepository.list(org_id, post[:post_id])
      post.merge(
        comments: comments,
        attachments: attachments.map { |a|
          { attachment_id: a[:attachment_id], original_filename: a[:original_filename], content_type: a[:content_type], file_size: a[:file_size] }
        }
      )
    end
  end

  def self.add_attachment(org_id, post_id, uploaded_file)
    PostAttachmentsRepository.create(org_id, post_id, uploaded_file)
  end

  def self.delete(org_id, post_id)
    OrgPostsRepository.delete(org_id, post_id)
  end
end
