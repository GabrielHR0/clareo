class PublicInstitutionsController < ApplicationController
  skip_before_action :authenticate!

  def show
    org = OrganizationsRepository.find(params[:id])
    return head :not_found unless org

    org_id = org[:organization_id]
    campaigns = CampaignsRepository.list(org_id, 100)

    org_expenses = ExpenseEntriesRepository.list_by_org(org_id, 200)
    enriched_org_expenses = org_expenses.map do |e|
      attachments = ExpenseAttachmentsRepository.list(org_id, e[:campaign_id], e[:entry_id])
      e.merge(attachments: attachments.map { |a| attachment_to_public_hash(a) })
    end

    campaign_expenses_map = {}
    campaigns.each do |c|
      expenses = ExpenseEntriesRepository.list(org_id, c[:campaign_id], 100)
      enriched = expenses.map do |e|
        attachments = ExpenseAttachmentsRepository.list(org_id, c[:campaign_id], e[:entry_id])
        e.merge(attachments: attachments.map { |a| attachment_to_public_hash(a) })
      end
      campaign_expenses_map[c[:campaign_id]] = enriched
    end

    posts = OrgPostService.list_with_comments(org_id, 50)

    render json: {
      organization: {
        organization_id: org[:organization_id].to_s,
        name: org[:name],
        contact_email: org[:contact_email],
        status: org[:status]
      },
      campaigns: campaigns.map { |c|
        c.merge(expenses: campaign_expenses_map[c[:campaign_id]] || [])
      },
      org_expenses: enriched_org_expenses,
      feed_posts: posts
    }
  end

  private

  def attachment_to_public_hash(a)
    {
      attachment_id: a[:attachment_id],
      original_filename: a[:original_filename],
      content_type: a[:content_type],
      file_size: a[:file_size]
    }
  end
end
