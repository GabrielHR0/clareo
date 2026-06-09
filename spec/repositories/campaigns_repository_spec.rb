require 'rails_helper'

RSpec.describe "CampaignsRepository" do
  let(:org_id) { "72f0ded1-11b4-471a-9a91-e2ce7ffb1c66" }
  let(:attrs) do
    {
      organization_id: org_id,
      name: "Repo Test",
      goal_cents: 50000,
      status: "draft"
    }
  end

  describe ".create" do
    it "creates a campaign and returns ids" do
      result = CampaignsRepository.create(attrs)
      expect(result).to have_key(:campaign_id)
      expect(result).to have_key(:organization_id)
    end
  end

  describe ".find" do
    it "finds a campaign by org and campaign id" do
      result = CampaignsRepository.create(attrs)
      campaign = CampaignsRepository.find(org_id, result[:campaign_id])
      expect(campaign).not_to be_nil
      expect(campaign[:name]).to eq("Repo Test")
      expect(campaign[:goal_cents]).to eq(50000)
      expect(campaign[:status]).to eq("draft")
    end

    it "returns nil for unknown campaign" do
      campaign = CampaignsRepository.find(org_id, "00000000-0000-0000-0000-000000000000")
      expect(campaign).to be_nil
    end
  end

  describe ".list" do
    it "lists all campaigns for an organization" do
      CampaignsRepository.create(attrs)
      list = CampaignsRepository.list(org_id)
      expect(list).to be_an(Array)
      expect(list.size).to be >= 1
    end
  end

  describe ".update" do
    let!(:created) { CampaignsRepository.create(attrs) }

    it "persists changes to name, description, status, goal_cents" do
      campaign = CampaignsRepository.find(org_id, created[:campaign_id])
      updated_attrs = campaign.merge(
        name: "Updated Name",
        description: "Updated desc",
        status: "active",
        goal_cents: 99999
      )
      CampaignsRepository.update(updated_attrs)

      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:name]).to eq("Updated Name")
      expect(reloaded[:description]).to eq("Updated desc")
      expect(reloaded[:status]).to eq("active")
      expect(reloaded[:goal_cents]).to eq(99999)
    end

    it "persists status change" do
      campaign = CampaignsRepository.find(org_id, created[:campaign_id])
      campaign[:status] = "active"
      CampaignsRepository.update(campaign)
      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:status]).to eq("active")
    end

    it "persists tags" do
      campaign = CampaignsRepository.find(org_id, created[:campaign_id])
      campaign[:tags] = ["tag1", "tag2"]
      CampaignsRepository.update(campaign)
      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:tags]).to match_array(["tag1", "tag2"])
    end

    it "persists goal_cents change" do
      campaign = CampaignsRepository.find(org_id, created[:campaign_id])
      campaign[:goal_cents] = 99999
      CampaignsRepository.update(campaign)
      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:goal_cents]).to eq(99999)
    end

    it "preserves created_at across updates" do
      campaign = CampaignsRepository.find(org_id, created[:campaign_id])
      original_created_at = campaign[:created_at]
      campaign[:name] = "NewName"
      CampaignsRepository.update(campaign)
      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:created_at]).to eq(original_created_at)
    end
  end

  describe "CampaignService.update via ActionController::Parameters" do
    let!(:created) { CampaignsRepository.create(attrs) }

    it "persists changes when passed ActionController::Parameters" do
      cap = ActionController::Parameters.new(
        "name" => "Service Updated",
        "status" => "active"
      ).permit(:name, :status)

      result = CampaignService.update(org_id, created[:campaign_id], cap)

      expect(result[:name]).to eq("Service Updated")
      expect(result[:status]).to eq("active")

      reloaded = CampaignsRepository.find(org_id, created[:campaign_id])
      expect(reloaded[:name]).to eq("Service Updated")
      expect(reloaded[:status]).to eq("active")
    end
  end
end
