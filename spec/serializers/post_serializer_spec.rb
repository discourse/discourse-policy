# frozen_string_literal: true

require 'rails_helper'

describe 'post serializer' do
  fab!(:group) { Fabricate(:group) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  before do
    Jobs.run_immediately!

    group.add(user1)
    group.add(user2)
  end

  it 'includes users in the serializer' do
    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    accepted = json[:post][:policy_accepted_by]

    expect(accepted.length).to eq(0)

    not_accepted = json[:post][:policy_not_accepted_by]

    expect(not_accepted.map { |u| u[:id] }.sort).to eq([user1.id, user2.id].sort)

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: Guardian.new).as_json

    not_accepted = json[:post][:policy_not_accepted_by]
    accepted = json[:post][:policy_accepted_by]

    expect(not_accepted.map { |u| u[:id] }.sort).to eq([user2.id].sort)
    expect(accepted.map { |u| u[:id] }.sort).to eq([user1.id].sort)
  end

  it 'does not include users if private' do
    raw = <<~MD
     [policy group=#{group.name} private=true]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))
    post.reload

    PolicyUser.add!(user1, post.post_policy)

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    expect(json[:post][:policy_not_accepted_by]).to eq(nil)
    expect(json[:post][:policy_accepted_by]).to eq(nil)
  end
end
