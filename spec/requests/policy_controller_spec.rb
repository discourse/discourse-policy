# frozen_string_literal: true

require "rails_helper"

describe DiscoursePolicy::PolicyController do
  fab!(:group) { Fabricate(:group) }
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:user1) { Fabricate(:user) }
  fab!(:user2) { Fabricate(:user) }

  before do
    Jobs.run_immediately!
    group.add(user1)
    group.add(user2)
  end

  it 'can allows users to accept/reject policy' do
    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: moderator)

    sign_in(user1)
    put "/policy/accept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([user1.id])

    sign_in(user2)
    put "/policy/accept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id).sort).to eq([user1.id, user2.id])

    put "/policy/unaccept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)
    expect(post.reload.post_policy.accepted_by.map(&:id)).to eq([user1.id])
  end

  describe '#accepted' do
    before do
      sign_in(user1)
    end

    it 'returns pages of users who accepted' do
      raw = <<~MD
       [policy groups=#{group.name}]
       I always open **doors**!
       [/policy]
      MD

      post = create_post(raw: raw, user: moderator)
      PolicyUser.add!(user1, post.post_policy)
      PolicyUser.add!(user2, post.post_policy)

      get "/policy/accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly(user1.id, user2.id)

      get "/policy/accepted.json", params: { post_id: post.id, offset: 1 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly(user2.id)

      get "/policy/accepted.json", params: { post_id: post.id, offset: 2 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly()
    end
  end

  describe '#not_accepted' do
    before do
      sign_in(user1)
    end

    it 'returns pages of users who accepted' do
      raw = <<~MD
       [policy group=#{group.name}]
       I always open **doors**!
       [/policy]
      MD

      post = create_post(raw: raw, user: moderator)

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 0 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly(user1.id, user2.id)

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 1 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly(user2.id)

      get "/policy/not-accepted.json", params: { post_id: post.id, offset: 2 }
      expect(response.status).to eq(200)
      expect(response.parsed_body['users'].map { |x| x['id'] }).to contain_exactly()
    end
  end
end
