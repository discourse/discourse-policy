require 'rails_helper'

describe 'post serializer' do
  it 'includes users in the serializer' do
    group = Fabricate(:group)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    group.add(user1)
    group.add(user2)

    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw, user: Fabricate(:admin))

    json = PostSerializer.new(post, scope: Guardian.new).as_json
    accepted = json[:post][:policy_accepted_by]

    expect(accepted.length).to eq(0)

    not_accepted = json[:post][:policy_not_accepted_by]

    expect(not_accepted.map { |u| u[:id] }.sort).to eq([user1.id, user2.id].sort)

    post.custom_fields[DiscoursePolicy::AcceptedBy] = [user1.id]

    json = PostSerializer.new(post, scope: Guardian.new).as_json

    not_accepted = json[:post][:policy_not_accepted_by]
    accepted = json[:post][:policy_accepted_by]

    expect(not_accepted.map { |u| u[:id] }.sort).to eq([user2.id].sort)
    expect(accepted.map { |u| u[:id] }.sort).to eq([user1.id].sort)
  end
end
