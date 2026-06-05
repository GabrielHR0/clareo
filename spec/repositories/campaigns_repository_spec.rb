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
end
