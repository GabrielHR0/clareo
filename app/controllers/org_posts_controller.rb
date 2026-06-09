class OrgPostsController < ApplicationController
  skip_before_action :authenticate!, only: [:index]

  def index
    org_id = params[:organization_id]
    limit = params[:limit]&.to_i&.clamp(1, 100) || 50
    posts = OrgPostService.list_with_comments(org_id, limit)
    render json: posts
  end

  def create
    org_id = params[:organization_id]
    attrs = post_params.merge(organization_id: org_id)

    if @current_user
      attrs[:author_id] = @current_user[:user_id]
      attrs[:author_type] = "user"
      attrs[:author_name] = @current_user[:name]
    end

    result = OrgPostService.create(attrs)
    post_id = result[:post_id]

    if params[:files].present?
      files = params[:files].is_a?(Array) ? params[:files] : [params[:files]]
      files.each do |file|
        OrgPostService.add_attachment(org_id, post_id, file)
      end
    end

    post = OrgPostService.list_with_comments(org_id, 1).first
    render json: post, status: :created
  rescue OrgPostService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    org_id = params[:organization_id]
    OrgPostService.delete(org_id, params[:id])
    head :ok
  end

  private

  def post_params
    params.require(:post).permit(:content)
  end
end
