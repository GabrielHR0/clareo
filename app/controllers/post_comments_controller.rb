class PostCommentsController < ApplicationController
  skip_before_action :authenticate!, only: [:index]

  def index
    post_id = params[:post_id]
    limit = params[:limit]&.to_i&.clamp(1, 100) || 50
    comments = PostCommentService.list(post_id, limit)
    render json: comments
  end

  def create
    attrs = comment_params.merge(post_id: params[:post_id])

    if @current_user
      attrs[:author_id] = @current_user[:user_id]
      attrs[:author_type] = "user"
      attrs[:author_name] = @current_user[:name]
    end

    comment = PostCommentService.create(attrs)
    render json: comment, status: :created
  rescue PostCommentService::ValidationError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def destroy
    PostCommentService.delete(params[:post_id], params[:id])
    head :ok
  end

  private

  def comment_params
    params.require(:comment).permit(:content)
  end
end
