class PostAttachmentsController < ApplicationController
  skip_before_action :authenticate!, only: [:download]

  def download
    org_id = params[:organization_id]
    post_id = params[:post_id]
    attachment_id = params[:attachment_id]

    record = PostAttachmentsRepository.list(org_id, post_id).find { |a| a[:attachment_id] == attachment_id }
    return head :not_found unless record

    file_path = PostAttachmentsRepository::STORAGE_ROOT.join(record[:file_path])
    return head :not_found unless File.exist?(file_path)

    send_file file_path, filename: record[:original_filename], type: record[:content_type]
  end
end
