require "rails_helper"

describe DiscoursePolicy::PolicyController do

  it 'can allows users to accept/reject policy' do

    group = Fabricate(:group)
    user1 = Fabricate(:user)
    user2 = Fabricate(:user)

    group.add(user1)
    group.add(user2)

    sign_in(user1)

    raw = <<~MD
     [policy group=#{group.name}]
     I always open **doors**!
     [/policy]
    MD

    post = create_post(raw: raw)

    put "/policy/accept.json", params: { post_id: post.id }

    expect(response.status).to eq(200)
    post.reload

    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq([user1.id])

    put "/policy/unaccept.json", params: { post_id: post.id }
    expect(response.status).to eq(200)

    post = Post.find(post.id)

    expect(post.custom_fields[DiscoursePolicy::AcceptedBy]).to eq(nil)
  end
end
