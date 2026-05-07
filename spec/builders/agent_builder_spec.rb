require 'rails_helper'

RSpec.describe AgentBuilder, type: :model do
  subject(:agent_builder) { described_class.new(params) }

  let(:account) { create(:account) }
  let!(:current_user) { create(:user, account: account) }
  let(:email) { 'test@example.com' }
  let(:name) { 'Test User' }
  let(:role) { 'agent' }
  let(:availability) { 'offline' }
  let(:auto_offline) { false }
  let(:params) do
    {
      email: email,
      name: name,
      inviter: current_user,
      account: account,
      role: role,
      availability: availability,
      auto_offline: auto_offline
    }
  end

  describe '#perform' do
    context 'when user does not exist' do
      it 'creates a new user' do
        expect { agent_builder.perform }.to change(User, :count).by(1)
      end

      it 'creates a new account user' do
        expect { agent_builder.perform }.to change(AccountUser, :count).by(1)
      end

      it 'returns a user' do
        expect(agent_builder.perform).to be_a(User)
      end
    end

    context 'when user exists' do
      before do
        create(:user, email: email)
      end

      it 'does not create a new user' do
        expect { agent_builder.perform }.not_to change(User, :count)
      end

      it 'creates a new account user' do
        expect { agent_builder.perform }.to change(AccountUser, :count).by(1)
      end
    end

    context 'when only email is provided' do
      let(:params) { { email: email, inviter: current_user, account: account } }

      it 'creates a user with default values' do
        user = agent_builder.perform
        expect(user.name).to eq('')
        expect(AccountUser.find_by(user: user).role).to eq('agent')
      end
    end

    context 'when a temporary password is generated' do
      it 'sets a temporary password for the user' do
        user = agent_builder.perform
        expect(user.encrypted_password).not_to be_empty
      end
    end

    context 'when the account already has inboxes' do
      let!(:inbox_one) { create(:inbox, account: account) }
      let!(:inbox_two) { create(:inbox, account: account) }
      let!(:inbox_three) { create(:inbox, account: account) }

      it 'attaches a new agent to every inbox' do
        user = agent_builder.perform

        expect(inbox_one.members).to include(user)
        expect(inbox_two.members).to include(user)
        expect(inbox_three.members).to include(user)
      end

      context 'when the role is administrator' do
        let(:role) { 'administrator' }

        it 'does not create inbox_members rows' do
          expect { agent_builder.perform }.not_to change(InboxMember, :count)
        end
      end

      context 'when the user has a stale inbox_member row from a prior membership' do
        before do
          orphan_user = create(:user, email: email)
          inbox_two.inbox_members.create!(user_id: orphan_user.id)
        end

        it 'does not raise on the duplicate and still attaches the rest' do
          expect { agent_builder.perform }.not_to raise_error
          user = User.from_email(email)
          expect(inbox_one.members).to include(user)
          expect(inbox_two.members).to include(user)
          expect(inbox_three.members).to include(user)
        end
      end
    end

    context 'when the account has no inboxes' do
      it 'does not raise and creates no inbox_members rows' do
        expect { agent_builder.perform }.not_to change(InboxMember, :count)
      end
    end
  end
end
