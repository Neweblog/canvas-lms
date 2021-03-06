require File.expand_path(File.dirname(__FILE__) + '/../sharding_spec_helper.rb')

describe SplitUsers do
  describe 'user splitting' do
    let!(:user1) { user_model }
    let!(:user2) { user_model }
    let(:user3) { user_model }
    let(:course1) { course(active_all: true) }
    let(:course2) { course(active_all: true) }
    let(:course3) { course(active_all: true) }
    let(:account1) { Account.default }
    let(:sub_account) { account1.sub_accounts.create! }

    it 'should restore pseudonyms to the original user' do
      pseudonym1 = user1.pseudonyms.create!(unique_id: 'sam1@example.com')
      pseudonym2 = user2.pseudonyms.create!(unique_id: 'sam2@example.com')
      pseudonym3 = user2.pseudonyms.create!(unique_id: 'sam3@example.com')
      UserMerge.from(user2).into(user1)
      SplitUsers.split_db_users(user1)

      user1.reload
      user2.reload
      expect(pseudonym1.user).to eq user1
      expect(pseudonym2.user).to eq user2
      expect(pseudonym3.user).to eq user2
    end

    describe 'with merge data' do

      it 'should split multiple users if no merge_data is specified' do
        enrollment1 = course1.enroll_user(user1)
        enrollment2 = course1.enroll_student(user2, enrollment_state: 'active')
        enrollment3 = course2.enroll_student(user1, enrollment_state: 'active')
        enrollment4 = course3.enroll_teacher(user1)
        enrollment5 = course1.enroll_teacher(user3)
        UserMerge.from(user1).into(user2)
        UserMerge.from(user3).into(user2)
        SplitUsers.split_db_users(user2)

        user1.reload
        user2.reload
        user3.reload
        expect(user1).not_to be_deleted
        expect(user2).not_to be_deleted
        expect(user3).not_to be_deleted
        expect(enrollment1.reload.user).to eq user1
        expect(enrollment2.reload.user).to eq user2
        expect(enrollment3.reload.user).to eq user1
        expect(enrollment4.reload.user).to eq user1
        expect(enrollment5.reload.user).to eq user3
      end

      it 'should only split users from merge_data when specified' do
        enrollment1 = course1.enroll_user(user1)
        enrollment2 = course1.enroll_student(user2, enrollment_state: 'active')
        enrollment3 = course2.enroll_student(user1, enrollment_state: 'active')
        enrollment4 = course3.enroll_teacher(user1)
        enrollment5 = course1.enroll_teacher(user3)
        UserMerge.from(user1).into(user2)
        UserMerge.from(user3).into(user2)
        merge_data = UserMergeData.where(user_id: user2, from_user: user1).first
        SplitUsers.split_db_users(user2, merge_data)

        user1.reload
        user2.reload
        user3.reload
        expect(user1).not_to be_deleted
        expect(user2).not_to be_deleted
        expect(user3).to be_deleted
        expect(enrollment1.reload.user).to eq user1
        expect(enrollment2.reload.user).to eq user2
        expect(enrollment3.reload.user).to eq user1
        expect(enrollment4.reload.user).to eq user1
        expect(enrollment5.reload.user).to eq user2
      end
    end

    it 'should restore submissions' do
      course1.enroll_student(user1, enrollment_state: 'active')
      assignment = course1.assignments.new(title: "some assignment")
      assignment.workflow_state = "published"
      assignment.save
      valid_attributes = {assignment_id: assignment.id, user_id: user1.id, grade: "1.5", url: "www.instructure.com"}
      submission = Submission.create!(valid_attributes)

      UserMerge.from(user1).into(user2)
      expect(submission.reload.user).to eq user2
      SplitUsers.split_db_users(user2)
      expect(submission.reload.user).to eq user1
    end

    it 'should restore admins' do
      admin = account1.account_users.create(user: user1)
      admin2 = sub_account.account_users.create(user: user2)
      UserMerge.from(user1).into(user2)

      user1.reload
      user2.reload
      expect(admin.user).to eq user1
      expect(admin2.user).to eq user2
    end

    context 'sharding' do
      specs_require_sharding

      it 'should merge a user across shards' do
        user1 = user_with_pseudonym(username: 'user1@example.com', active_all: 1)
        p1 = @pseudonym
        @shard1.activate do
          account = Account.create!
          @user2 = user_with_pseudonym(username: 'user2@example.com', active_all: 1, account: account)
          @p2 = @pseudonym
          UserMerge.from(user1).into(@user2)
          SplitUsers.split_db_users(@user2)
        end

        user1.reload
        @user2.reload

        expect(user1).not_to be_deleted
        expect(p1.reload.user).to eq user1
        expect(@user2.all_pseudonyms).to eq [@p2]
      end
    end
  end
end
