# frozen_string_literal: true

RSpec.describe "Core features", type: :system do
  before { SiteSetting.policy_enabled = true }

  it_behaves_like "having working core features"
end
