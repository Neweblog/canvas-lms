require_relative '../common'
require_relative '../helpers/quizzes_common'
require_relative '../helpers/assignment_overrides'
require_relative '../helpers/files_common'

describe "quizzes" do
  include_context "in-process server selenium tests"
  include QuizzesCommon
  include AssignmentOverridesSeleniumHelper
  include FilesCommon

  def add_question_to_group
    f('.add_question_link').click
    wait_for_ajaximations
    question_form = f('.question_form')
    submit_form(question_form)
    wait_for_ajaximations
  end

  context "as a teacher" do

    before(:each) do
      course_with_teacher_logged_in
      course_with_student(course: @course, active_enrollment: true)
      @course.update_attributes(:name => 'teacher course')
      @course.save!
      @course.reload
    end

    it "should show a summary of due dates if there are multiple", priority: "1", test_id: 210054 do
      create_quiz_with_due_date
      get "/courses/#{@course.id}/quizzes"
      expect(f('.item-group-container .date-available')).not_to include_text "Multiple Dates"
      add_due_date_override(@quiz)

      get "/courses/#{@course.id}/quizzes"
      expect(f('.item-group-container .date-available')).to include_text "Multiple Dates"
      driver.mouse.move_to f('.item-group-container .date-available')
      wait_for_ajaximations
      tooltip = fj('.ui-tooltip:visible')
      expect(tooltip).to include_text 'New Section'
      expect(tooltip).to include_text 'Everyone else'
    end

    it "should asynchronously load student quiz results", priority: "2", test_id: 210058 do
      @context = @course
      q = quiz_model
      q.generate_quiz_data
      q.save!

      get "/courses/#{@course.id}/quizzes/#{q.id}"
      f('.al-trigger').click
      f('.quiz_details_link').click
      wait_for_ajaximations
      expect(f('#quiz_details')).to be_displayed
    end

    it "should create a new question group", priority: "1", test_id: 210060 do
      get "/courses/#{@course.id}/quizzes/new"

      click_questions_tab
      f('.add_question_group_link').click
      group_form = f('#questions .quiz_group_form')
      group_form.find_element(:name, 'quiz_group[name]').send_keys('new group')
      replace_content(group_form.find_element(:name, 'quiz_group[question_points]'), '3')
      submit_form(group_form)
      expect(group_form.find_element(:css, '.group_display.name')).to include_text('new group')
    end

    it 'should display post to SIS icon on quiz page when enabled' do
      Account.default.set_feature_flag!('post_grades', 'on')

      @q1 = quiz_create
      @q2 = quiz_create
      @q3 = quiz_create

      @q1.post_to_sis = true
      @q2.post_to_sis = false
      @q3.post_to_sis = true

      @q1.save!
      @q2.save!
      @q3.save!

      get "/courses/#{@course.id}/quizzes/"
      wait_for_ajaximations

      expect(find_all('.post-to-sis-status.enabled').count).to be 2
      expect(find_all('.post-to-sis-status.disabled').count).to be 1

      Account.default.set_feature_flag!('post_grades', 'off')

      get "/courses/#{@course.id}/quizzes/"
      wait_for_ajaximations

      expect(find_all('.post-to-sis-status.enabled').count).to be 0
      expect(find_all('.post-to-sis-status.disabled').count).to be 0
    end

    it 'should display post to SIS icon on quiz page when enabled' do
      Account.default.set_feature_flag!('post_grades', 'on')

      @q1 = quiz_create
      @q2 = quiz_create
      @q3 = quiz_create

      @q1.post_to_sis = true
      @q2.post_to_sis = false
      @q3.post_to_sis = true

      @q1.save!
      @q2.save!
      @q3.save!

      get "/courses/#{@course.id}/quizzes/"
      wait_for_ajaximations

      enabled = find_all('.post-to-sis-status.enabled')
      disabled = find_all('.post-to-sis-status.disabled')

      expect(enabled.count).to be 2
      expect(disabled.count).to be 1

      enabled.each(&:click)
      disabled.each(&:click)

      wait_for_ajaximations

      @q1.reload
      @q2.reload
      @q3.reload

      expect(@q1.post_to_sis?).to be_falsey
      expect(@q2.post_to_sis?).to be_truthy
      expect(@q3.post_to_sis?).to be_falsey

      expect(find_all('.post-to-sis-status.enabled').count).to be 1
      expect(find_all('.post-to-sis-status.disabled').count).to be 2
    end

    it "should update a question group", priority: "1", test_id: 210061 do
      skip('fragile')
      get "/courses/#{@course.id}/quizzes/new"

      click_questions_tab
      f('.add_question_group_link').click
      group_form = f('#questions .quiz_group_form')
      group_form.find_element(:name, 'quiz_group[name]').send_keys('new group')
      replace_content(group_form.find_element(:name, 'quiz_group[question_points]'), '3')
      submit_form(group_form)
      expect(group_form.find_element(:css, '.group_display.name')).to include_text('new group')

      expect(f("#quiz_display_points_possible .points_possible").text).to eq "0"

      add_question_to_group
      click_settings_tab
      keep_trying_until { expect(f("#quiz_display_points_possible .points_possible").text).to eq "3" }

      click_questions_tab
      group_form.find_element(:css, '.edit_group_link').click

      group_form.find_element(:name, 'quiz_group[name]').send_keys('renamed')
      replace_content(group_form.find_element(:name, 'quiz_group[question_points]'), '2')
      submit_form(group_form)
      expect(group_form.find_element(:css, '.group_display.name')).to include_text('renamed')
      click_settings_tab
      keep_trying_until { expect(f("#quiz_display_points_possible .points_possible").text).to eq "2" }
    end

    it "should not let you exceed the question limit", priority: "2", test_id: 210062 do
      get "/courses/#{@course.id}/quizzes/new"

      click_questions_tab
      f('.add_question_group_link').click
      group_form = f('#questions .quiz_group_form')
      pick_count_field = group_form.find_element(:name, 'quiz_group[pick_count]')
      pick_count = lambda do |count|
        driver.execute_script <<-JS
          var $pickCount = $('#questions .group_top input[name="quiz_group[pick_count]"]');
          $pickCount.focus();
          $pickCount[0].value = #{count.to_s.inspect};
          $pickCount.change();
        JS
      end

      pick_count.call('1001')
      dismiss_alert
      expect(pick_count_field).to have_attribute(:value, "1")

      click_new_question_button # 1 total, ok
      group_form.find_element(:css, '.edit_group_link').click
      pick_count.call('999') # 1000 total, ok

      click_new_question_button # 1001 total, bad
      dismiss_alert

      pick_count.call('1000') # 1001 total, bad
      dismiss_alert
      expect(pick_count_field).to have_attribute(:value, "999")
    end

    describe "insufficient count warnings" do
      it "should show a warning for groups picking too many questions", priority: "2", test_id: 539340 do
        get "/courses/#{@course.id}/quizzes/new"
        click_questions_tab
        f('.add_question_group_link').click
        submit_form('.quiz_group_form')
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to be_displayed

        add_question_to_group
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to_not be_displayed

        f('#questions .edit_group_link').click
        replace_content(f('#questions .group_top input[name="quiz_group[pick_count]"]'), '2')
        submit_form('.quiz_group_form')
        wait_for_ajaximations
        expect(f(".insufficient_count_warning")).to be_displayed

        # save and reload
        expect_new_page_load{ f('.save_quiz_button').click }
        quiz = @course.quizzes.last
        get "/courses/#{@course.id}/quizzes/#{quiz.id}/edit"

        click_questions_tab
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to be_displayed

        add_question_to_group
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to_not be_displayed
      end

      it "should show a warning for groups picking too many questions from a bank", priority: "2", test_id: 539341 do
        bank = @course.assessment_question_banks.create!
        assessment_question_model(bank: bank)

        get "/courses/#{@course.id}/quizzes/new"
        click_questions_tab
        f('.add_question_group_link').click

        f('.find_bank_link').click
        keep_trying_until { fj('#find_bank_dialog .bank:visible') }.click
        submit_dialog('#find_bank_dialog', '.submit_button')
        submit_form('.quiz_group_form')
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to_not be_displayed

        f('#questions .edit_group_link').click
        replace_content(f('#questions .group_top input[name="quiz_group[pick_count]"]'), '2')
        submit_form('.quiz_group_form')
        wait_for_ajaximations
        expect(f(".insufficient_count_warning")).to be_displayed

        # save and reload
        expect_new_page_load{ f('.save_quiz_button').click }
        quiz = @course.quizzes.last
        get "/courses/#{@course.id}/quizzes/#{quiz.id}/edit"

        click_questions_tab
        wait_for_ajaximations

        expect(f(".insufficient_count_warning")).to be_displayed

        f('#questions .edit_group_link').click
        replace_content(f('#questions .group_top input[name="quiz_group[pick_count]"]'), '1')
        submit_form('.quiz_group_form')
        wait_for_ajaximations
        expect(f(".insufficient_count_warning")).to_not be_displayed
      end
    end

    describe "moderation" do

      before do
        @student = user_with_pseudonym(:active_user => true, :username => 'student@example.com', :password => 'qwerty')
        @course.enroll_user(@student, "StudentEnrollment", :enrollment_state => 'active')
        @context = @course
        @quiz = quiz_model
        @quiz.time_limit = 20
        @quiz.generate_quiz_data
        @quiz.save!
      end

      it "should moderate quiz", priority: "1", test_id: 210063 do
        get "/courses/#{@course.id}/quizzes/#{@quiz.id}/moderate"
        f('.moderate_student_link').click

        # validates data
        f('#extension_extra_attempts').send_keys('asdf')
        submit_form('#moderate_student_form')
        expect(f('.attempts_left').text).to eq '1'

        # valid values
        f('#extension_extra_attempts').clear()
        f('#extension_extra_attempts').send_keys('2')
        submit_form('#moderate_student_form')
        wait_for_ajax_requests
        expect(f('.attempts_left').text).to eq '3'
      end

      it "should preserve extra time values", priority: "2", test_id: 210064 do
        get "/courses/#{@course.id}/quizzes/#{@quiz.id}/moderate"
        f('.moderate_student_link').click

        # initial data entry
        f('#extension_extra_time').send_keys('13')
        submit_form('#moderate_student_form')
        wait_for_ajax_requests

        # preserve values between moderation invocations
        expect(f('.extra_time_allowed').text).to eq 'gets 13 extra minutes on each attempt'
        f('.moderate_student_link').click
        expect(f('#extension_extra_time').attribute('value')).to eq '13'
      end

    end

    it "should indicate when it was last saved", priority: "1", test_id: 210065 do
      user_session(@student)
      take_quiz do
        indicator = f('#last_saved_indicator')
        expect(indicator.text).to eq 'Not saved'
        f('.answer .question_input').click

        # too fast, this always fails
        # indicator.text.should == 'Saving...'

        wait_for_ajax_requests
        expect(indicator.text).to match(/^Quiz saved at \d+:\d+(pm|am)$/)
      end
      user_session(@user)
    end

    it "should validate numerical input data", priority: "1", test_id: 210066 do
      @quiz = quiz_with_new_questions do |bank, quiz|
        aq = bank.assessment_questions.create!
        quiz.quiz_questions.create!(:question_data => {:name => "numerical", 'question_type' => 'numerical_question', 'answers' => [], :points_possible => 1}, :assessment_question => aq)
      end
      user_session(@student)
      take_quiz do
        input = f('.numerical_question_input')

        input.click
        input.send_keys('asdf')
        wait_for_ajaximations
        expect(error_displayed?).to be_truthy
        driver.execute_script('$(".numerical_question_input").change()')
        wait_for_ajaximations
        expect(input[:value]).to be_blank

        input.click
        input.send_keys('1')
        wait_for_ajaximations
        expect(error_displayed?).to be_falsey
        driver.execute_script('$(".numerical_question_input").change()')
        wait_for_ajaximations
        expect(input).to have_attribute(:value, "1.0000")
      end
      user_session(@user)
    end

    it "should mark dropdown questions as answered", priority: "2", test_id: 210067 do
      skip("xvfb issues")
      @quiz = quiz_with_new_questions do |bank, quiz|
        aq1 = AssessmentQuestion.create!
        aq2 = AssessmentQuestion.create!
        bank.assessment_questions << aq1
        bank.assessment_questions << aq2
        q1 = quiz.quiz_questions.create!(:assessment_question => aq1)
        q1.write_attribute(
          :question_data, {
            :name => "dropdowns",
            :question_type => 'multiple_dropdowns_question',
            :answers => [
              {
                :weight => 100,
                :text => "orange",
                :blank_id => "orange",
                :id => 1
              }, {
                :weight => 0,
                :text => "rellow",
                :blank_id => "orange",
                :id => 2
              }, {
                :weight => 100,
                :text => "green",
                :blank_id => "green",
                :id => 3
              }, {
                :weight => 0,
                :text => "yellue",
                :blank_id => "green",
                :id => 4
              }
            ],
            :question_text => "<p>multiple answers red + yellow = [orange], yellow + blue = [green]</p>",
            :points_possible => 1
          }
        )
        q1.save!
        q2 = quiz.quiz_questions.create!(:assessment_question => aq2)
        q2.write_attribute(
          :question_data, {
            :name => "matching",
            :question_type => 'matching_question',
            :matches => [
              {
                :match_id => 1,
                :text => "north"
              }, {
                :match_id => 2,
                :text => "south"
              }, {
                :match_id => 3,
                :text => "east"
              }, {
                :match_id => 4,
                :text => "west"
              }
            ],
            :answers => [
              {
                :left => "nord",
                :text => "nord",
                :right => "north",
                :match_id => 1
              }, {
                :left => "sud",
                :text => "sud",
                :right => "south",
                :match_id => 2
              }, {
                :left => "est",
                :text => "est",
                :right => "east",
                :match_id => 3
              }, {
                :left => "ouest",
                :text => "ouest",
                :right => "west",
                :match_id => 4
              }
            ],
            :points_possible => 1
          }
        )
        q2.save!
      end

      take_quiz do
        dropdowns = ffj('a.ui-selectmenu.question_input')
        expect(dropdowns.size).to eq 6

        # partially answer each question
        [dropdowns.first, dropdowns.last].each do |d|
          d.click
          wait_for_ajaximations
          f('.ui-selectmenu-open li:nth-child(2)').click
          wait_for_ajaximations
        end
        # not marked as answered
        keep_trying_until { expect(ff('#question_list .answered')).to be_empty }

        # fully answer each question
        dropdowns.each do |d|
          d.click
          wait_for_ajaximations
          f('.ui-selectmenu-open li:nth-child(2)').click
          wait_for_ajaximations
        end

        # marked as answer
        keep_trying_until { expect(ff('#question_list .answered').size).to eq 2 }
        wait_for_ajaximations

        fln('Quizzes').click
        wait_for_ajaximations

        driver.switch_to.alert.accept
        wait_for_ajaximations

        get "/courses/#{@course.id}/quizzes/#{@quiz.id}"
        fln("Resume Quiz").click

        # there's some initial setTimeout stuff that happens, so things won't
        # be ready right when the page loads
        keep_trying_until do
          dropdowns = ff('a.ui-selectmenu.question_input')
          expect(dropdowns.size).to eq 6
          expect(dropdowns.map(&:text)).to eq %w{orange green east east east east}
        end
        expect(ff('#question_list .answered').size).to eq 2
      end
    end

    it "should give a student extra time if the time limit is extended", priority: "2", test_id: 210068 do
      @context = @course
      bank = @course.assessment_question_banks.create!(:title => 'Test Bank')
      q = quiz_model
      a = bank.assessment_questions.create!
      answers = [{id: 1, answer_text: 'A', weight: 100}, {id: 2, answer_text: 'B', weight: 0}]
      question = q.quiz_questions.create!(:question_data => {
          :name => "first question",
          'question_type' => 'multiple_choice_question',
          'answers' => answers,
          :points_possible => 1
      }, :assessment_question => a)

      q.generate_quiz_data
      q.time_limit = 10
      q.save!

      # This user action has to be done as a student
      user_session(@student)
      get "/courses/#{@course.id}/quizzes/#{q.id}/take"
      f("#take_quiz_link").click
      sleep 1

      answer_one = f("#question_#{question.id}_answer_1")

      # force a save to create a submission
      answer_one.click
      wait_for_ajaximations

      # restore user state, assuming specs aren't independent
      user_session(@user)

      # add time as a the moderator. this code replicates what happens in
      # QuizSubmissions#extensions when a moderator extends a student's
      # quiz time.

      quiz_original_end_time = Quizzes::QuizSubmission.last.end_at
      keep_trying_until do
        submission = Quizzes::QuizSubmission.last
        submission.end_at = Time.zone.now + 20.minutes
        submission.save!
        expect(quiz_original_end_time).to be < Quizzes::QuizSubmission.last.end_at
        expect(f('.time_running').text).to match /19 Minutes/
      end
    end

    def upload_attachment_answer
      fj('input[type=file]').send_keys @fullpath
      wait_for_ajaximations
      keep_trying_until do
        fj('.file-uploaded').text
        fj('.list_question, .answered').text
      end
      fj('.upload-label').click
      wait_for_ajaximations
    end

    def file_upload_submission_data
      @quiz.reload.quiz_submissions.first.
          submission_data["question_#{@question.id}".to_sym]
    end

    def file_upload_attachment
      @quiz.reload.quiz_submissions.first.attachments.first
    end


    it "works with file upload questions", priority: "1", test_id: 210071 do
      @context = @course
      bank = @course.assessment_question_banks.create!(:title => 'Test Bank')
      q = quiz_model
      a = bank.assessment_questions.create!
      answers = {'answer_0' => {'id' => 1}, 'answer_1' => {'id' => 2}}
      @question = q.quiz_questions.create!(:question_data => {
          :name => "first question",
          'question_type' => 'file_upload_question',
          'question_text' => 'file upload question maaaan',
          'answers' => answers,
          :points_possible => 1
      }, :assessment_question => a)
      q.generate_quiz_data
      q.save!
      _filename, @fullpath, _data = get_file "testfile1.txt"

      Setting.set('context_default_quota', '1') # shouldn't check quota

      user_session(@student)
      get "/courses/#{@course.id}/quizzes/#{q.id}/take"
      expect_new_page_load do
        f("#take_quiz_link").click
        # In this case the UI updates on a timer, not an ajax callback
        sleep 1
      end

      # so we can .send_keys to the input, can't if it's invisible to the browser
      driver.execute_script "$('.file-upload').removeClass('hidden')"
      upload_attachment_answer
      expect(file_upload_submission_data).to eq [file_upload_attachment.id.to_s]
      # delete the attachment id
      fj('.delete-attachment').click
      keep_trying_until { expect(fj('.answered')).to eq nil }

      fj('.upload-label').click
      wait_for_ajaximations
      keep_trying_until { expect(file_upload_submission_data).to eq [""] }
      upload_attachment_answer
      expect_new_page_load do
        driver.get driver.current_url
        driver.switch_to.alert.accept
      end
      wait_for_ajaximations
      attachment = file_upload_attachment
      expect(fj('.file-upload-box').text).to include attachment.display_name
      f('#submit_quiz_button').click
      wait_for_ajaximations
      keep_trying_until { expect(fj('.selected_answer').text).to include attachment.display_name }
      user_session(@user)
    end

    it "should notify a student of extra time given by a moderator", priority: "2", test_id: 210070 do
      skip('broken')
      @context = @course
      bank = @course.assessment_question_banks.create!(:title => 'Test Bank')
      q = quiz_model
      a = bank.assessment_questions.create!
      answers = {'answer_0' => {'id' => 1}, 'answer_1' => {'id' => 2}}
      question = q.quiz_questions.create!(:question_data => {
          :name => "first question",
          'question_type' => 'multiple_choice_question',
          'answers' => answers,
          :points_possible => 1
      }, :assessment_question => a)

      q.generate_quiz_data
      q.time_limit = 10
      q.save!

      get "/courses/#{@course.id}/quizzes/#{q.id}/take?user_id=#{@user.id}"
      expect_new_page_load do
        f("#take_quiz_link").click
        # In this case the UI updates on a timer, not an ajax callback
        sleep 1
      end

      answer_one = f("#question_#{question.id}_answer_1")

      # force a save to create a submission
      answer_one.click
      wait_for_ajaximations

      # add time as a the moderator. this code replicates what happens in
      # QuizSubmissions#extensions when a moderator extends a student's
      # quiz time.


      quiz_original_end_time = Quizzes::QuizSubmission.last.end_at


      submission = Quizzes::QuizSubmission.last
      submission.end_at = Time.zone.now + 20.minutes
      submission.save!

      expect(quiz_original_end_time).to be < Quizzes::QuizSubmission.last.end_at
      assert_flash_notice_message /You have been given extra time on this attempt/
      expect(f('.time_running').text).to match /19 Minutes/
    end

    it "should display a link to quiz statistics for a MOOC", priority: "2", test_id: 210072 do
      quiz_with_submission
      @course.large_roster = true
      @course.save!
      get "/courses/#{@course.id}/quizzes/#{@quiz.id}"

      expect(f('#right-side')).to include_text('Quiz Statistics')
    end

    it "should not allow a teacher to take a quiz" do
      @quiz = quiz_model({ course: @course, time_limit: 5 })
      @quiz.quiz_questions.create!(question_data: multiple_choice_question_data)
      @quiz.generate_quiz_data
      @quiz.save!

      get "/courses/#{@course.id}/quizzes/#{@quiz.id}/take"
      expect(ff("#take_quiz_link").size).to eq 0
    end
  end
end
