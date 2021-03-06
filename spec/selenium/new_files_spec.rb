require File.expand_path(File.dirname(__FILE__) + '/common')
require File.expand_path(File.dirname(__FILE__) + '/helpers/files_common')
require File.expand_path(File.dirname(__FILE__) + '/helpers/public_courses_context')

describe "better_file_browsing" do
  include_context "in-process server selenium tests"
  include FilesCommon

  context "As a teacher" do
    before(:each) do
      course_with_teacher_logged_in
      add_file(fixture_file_upload('files/example.pdf', 'application/pdf'),
               @course, "example.pdf")
      get "/courses/#{@course.id}/files"
    end
    it "should display new files UI", priority: "1", test_id: 133092 do
      expect(f('.btn-upload')).to be_displayed
      expect(all_files_folders.count).to eq 1
    end
    it "should load correct column values on uploaded file", priority: "1", test_id: 133129 do
      time_current = @course.attachments.first.updated_at.strftime("%l:%M%P").strip
      expect(ff('.media-body')[0].text).to eq 'example.pdf'
      expect(ff('.ef-date-created-col')[1].text).to eq time_current
      expect(ff('.ef-date-modified-col')[1].text).to eq time_current
      expect(ff('.ef-size-col')[1].text).to eq '194 KB'
    end

    context "from cog icon" do
      it "should edit file name", priority: "1", test_id: 133127 do
        expect(fln("example.pdf")).to be_present
        file_rename_to = "Example_edited.pdf"
        edit_name_from_cog_icon(file_rename_to)
        wait_for_ajaximations
        expect(fln("example.pdf")).not_to be_present
        expect(fln(file_rename_to)).to be_present
      end
      it "should delete file", priority: "1", test_id: 133128 do
        delete(0, :cog_icon)
        expect(all_files_folders.count).to eq 0
      end
    end

    context "from cloud icon" do
      it "should unpublish and publish a file", priority: "1", test_id: 133096 do
        set_item_permissions(:unpublish, :cloud_icon)
        expect(f('.btn-link.published-status.unpublished')).to be_displayed
        expect(driver.find_element(:class => 'unpublished')).to be_displayed
        set_item_permissions(:publish, :cloud_icon)
        expect(f('.btn-link.published-status.published')).to be_displayed
        expect(driver.find_element(:class => 'published')).to be_displayed
      end
      it "should make file available to student with link", priority: "1", test_id: 223504 do
        set_item_permissions(:restricted_access, :available_with_link, :cloud_icon)
        expect(f('.btn-link.published-status.hiddenState')).to be_displayed
        expect(driver.find_element(:class => 'hiddenState')).to be_displayed
      end
      it "should make file available to student within given timeframe", priority: "1", test_id: 223505 do
        set_item_permissions(:restricted_access, :available_with_timeline, :cloud_icon)
        expect(f('.btn-link.published-status.restricted')).to be_displayed
        expect(driver.find_element(:class => 'restricted')).to be_displayed
      end
    end

    context "from toolbar menu" do
      it "should delete file from toolbar", priority: "1", test_id: 133105 do
        delete(0, :toolbar_menu)
        expect(all_files_folders.count).to eq 0
      end
      it "should unpublish and publish a file", priority: "1", test_id: 223503 do
        set_item_permissions(:unpublish, :toolbar_menu)
        expect(f('.btn-link.published-status.unpublished')).to be_displayed
        expect(driver.find_element(:class => 'unpublished')).to be_displayed
        set_item_permissions(:publish, :toolbar_menu)
        expect(f('.btn-link.published-status.published')).to be_displayed
        expect(driver.find_element(:class => 'published')).to be_displayed
      end
      it "should make file available to student with link from toolbar", priority: "1", test_id: 193158 do
        set_item_permissions(:restricted_access, :available_with_link, :toolbar_menu)
        expect(f('.btn-link.published-status.hiddenState')).to be_displayed
        expect(driver.find_element(:class => 'hiddenState')).to be_displayed
      end
      it "should make file available to student within given timeframe from toolbar", priority: "1", test_id: 193159 do
        set_item_permissions(:restricted_access, :available_with_timeline, :toolbar_menu)
        expect(f('.btn-link.published-status.restricted')).to be_displayed
        expect(driver.find_element(:class => 'restricted')).to be_displayed
      end

      it "should disable the file preview button when a folder is selected" do
        add_folder('Testing')
        fj('.ef-item-row:contains("Testing")').click
        expect(f('.Toolbar__ViewBtn--onlyfolders')).to be_displayed
      end
    end

    context "accessibility tests for preview" do
      before do
        fln("example.pdf").click
      end
      it "tabs through all buttons in the header button bar", priority: "1", test_id: 193816 do
        buttons = ff('.ef-file-preview-header-buttons > *')
        driver.execute_script("$('.ef-file-preview-header-buttons').children().first().focus()")
        buttons.each do |button|
          check_element_has_focus(button)
          button.send_keys("\t")
        end
      end
      it "returns focus to the link that was clicked when closing with the esc key", priority: "1", test_id: 193817 do
        driver.execute_script('return document.activeElement').send_keys :escape
        check_element_has_focus(fln("example.pdf"))
      end
      it "returns focus to the link when the close button is clicked", priority: "1", test_id: 193818 do
        f('.ef-file-preview-header-close').click
        check_element_has_focus(fln("example.pdf"))
      end
    end

    context "accessibility tests for Toolbar Previews" do
      it "returns focus to the preview toolbar button when closed", priority: "1", test_id: 193819 do
        ff('.ef-item-row')[0].click
        f('.btn-view').click
        f('.ef-file-preview-header-close').click
        check_element_has_focus(f('.btn-view'))
      end
    end
  end

  context "when a public course is accessed" do
    include_context "public course as a logged out user"

    it "should display course files", priority: "1", test_id: 270032 do
      get "/courses/#{public_course.id}/files"
      expect(f('div.ef-main[data-reactid]')).to be_displayed
    end
  end

  context "Search textbox" do
    before(:each) do
      course_with_teacher_logged_in
      txt_files = ["a_file.txt", "b_file.txt", "c_file.txt"]
      txt_files.map do |text_file|
        add_file(fixture_file_upload("files/#{text_file}", 'text/plain'), @course, text_file)
      end
      get "/courses/#{@course.id}/files"
    end

    it "should search for a file", priority: "2", test_id: 220355 do
      edit_name_from_cog_icon("b_file1.txt")
      wait_for_ajaximations
      f("input[type='search']").send_keys "b_fi"
      driver.action.send_keys(:return).perform
      # Unable to find matching line from backtrace error is encountered if refresh_page is not used
      refresh_page
      expect(all_files_folders.count).to eq 2
    end
  end

  context "Move dialog" do
    before(:each) do
      course_with_teacher_logged_in
      txt_files = ["a_file.txt", "b_file.txt", "c_file.txt"]
      txt_files.map { |text_file| add_file(fixture_file_upload("files/#{text_file}", 'text/plain'), @course, text_file) }
      get "/courses/#{@course.id}/files"
    end
    it "should set focus to the folder tree when opening the dialog", priority: "1", test_id: 220356 do
      ff('.al-trigger')[0].click
      fln("Move").click
      wait_for_ajaximations
      check_element_has_focus(ff('.tree')[1])
    end
    it "should move a file using cog icon", priority: "1", test_id: 133103 do
      file_name = "a_file.txt"
      add_folder("destination_folder")
      move(file_name, 0, :cog_icon)
      wait_for_ajaximations
      expect(f("#flash_message_holder").text).to eq "#{file_name} moved to destination_folder\nClose"
      wait_for_ajaximations
      expect(ff('.media-body')[0].text).not_to eq file_name
      ff('.media-body')[2].click
      wait_for_ajaximations
      expect(fln(file_name)).to be_displayed
    end
    it "should move a file using toolbar menu", priority: "1", test_id: 217603 do
      file_name = "a_file.txt"
      add_folder("destination_folder")
      move(file_name, 0, :toolbar_menu)
      wait_for_ajaximations
      expect(f("#flash_message_holder").text).to eq "#{file_name} moved to destination_folder\nClose"
      wait_for_ajaximations
      expect(ff('.media-body')[0].text).not_to eq file_name
      ff('.media-body')[2].click
      wait_for_ajaximations
      expect(fln(file_name)).to be_displayed
    end
    it "should move multiple files", priority: "1", test_id: 220357 do
      files = ["a_file.txt", "b_file.txt", "c_file.txt"]
      add_folder("destination_folder")
      move_multiple_using_toolbar(files)
      wait_for_ajaximations
      expect(f("#flash_message_holder").text).to eq "#{files.count} items moved to destination_folder\nClose"
      wait_for_ajaximations
      expect(ff('.media-body')[0].text).not_to eq files[0]
      ff('.media-body')[0].click
      wait_for_ajaximations
      files.each do |file|
        expect(fln(file)).to be_displayed
      end
    end

    context "Search Results" do
      def search_and_move(file_name:  "", destination: "My Files")
        f("input[type='search']").send_keys file_name
        driver.action.send_keys(:return).perform
        # Unable to find matching line from backtrace error is encountered if refresh_page is not used
        refresh_page
        expect(all_files_folders.count).to eq 1
        move(file_name, 0, :cog_icon, destination)
        wait_for_ajaximations
        final_destination = destination.split('/').pop
        expect(f("#flash_message_holder").text).to eq "#{file_name} moved to #{final_destination}\nClose"
        wait_for_ajaximations
        fj("a.treeLabel span:contains('#{final_destination}')").click
        wait_for_ajaximations
        expect(fln(file_name)).to be_displayed
      end
      before(:each) do
        course_with_teacher_logged_in
        user_files = ["a_file.txt", "b_file.txt"]
        user_files.map { |text_file| add_file(fixture_file_upload("files/#{text_file}", 'text/plain'), @teacher, text_file) }
        # Course file
        add_file(fixture_file_upload("files/c_file.txt", 'text/plain'), @course, "c_file.txt")
      end

      it "should move a file to a destination if contexts are different" do
        get "/courses/#{@course.id}/files"
        folder_name = "destination_folder"
        add_folder(folder_name)
        get "/files"
        search_and_move(file_name: "a_file.txt", destination: "#{@course.name}/#{folder_name}")
      end

      it "should move a file to a destination if the contexts are the same" do
        get "/files"
        folder_name = "destination_folder"
        add_folder(folder_name)
        search_and_move(file_name: "a_file.txt", destination: "My Files/#{folder_name}")
      end
    end
  end

  context "File Downloads" do
    it "should download a file from top toolbar successfully" do
      skip("Skipped until issue with firefox on OSX is resolved")
      download_from_toolbar
    end
    it "should download a file from cog" do
      skip("Skipped until issue with firefox on OSX is resolved")
      download_from_cog_icon
    end
    it "should download a file from file preview successfully" do
      skip("Skipped until issue with firefox on OSX is resolved")
      download_from_preview
    end
  end

  context "Publish Cloud Dialog" do
    before(:each) do
      course_with_teacher_logged_in
      add_file(fixture_file_upload('files/a_file.txt', 'text/plain'),
               @course, "a_file.txt")
      get "/courses/#{@course.id}/files"
    end
    it "should validate that file is published by default", priority: "1", test_id: 193820 do
      expect(f('.btn-link.published-status.published')).to be_displayed
    end
    it "should set focus to the close button when opening the dialog", priority: "1", test_id: 194243 do
      f('.btn-link.published-status').click
      wait_for_ajaximations
      shouldFocus = f('.ui-dialog-titlebar-close')
      element = driver.execute_script('return document.activeElement')
      expect(element).to eq(shouldFocus)
    end
  end

  context "Usage Rights Dialog" do
    def set_usage_rights_in_modal(rights = 'creative_commons')
      set_value f('.UsageRightsSelectBox__select'), rights
      if rights == 'creative_commons'
        set_value f('.UsageRightsSelectBox__creativeCommons'), 'cc_by'
      end
      set_value f('#copyrightHolder'), 'Test User'
      f('.ReactModal__Footer-Actions .btn-primary').click
      wait_for_ajaximations
    end

    def verify_usage_rights_ui_updates(iconClass = 'icon-files-creative-commons')
      expect(f(".UsageRightsIndicator__openModal i.#{iconClass}")).to be_displayed
    end

    def react_modal_hidden
      expect(f('.ReactModal__Content')).to eq(nil)
    end

    before :each do
      course_with_teacher_logged_in
      Account.default.enable_feature!(:usage_rights_required)
      add_file(fixture_file_upload('files/a_file.txt', 'text/plan'),
               @course, "a_file.txt")
    end
    context "course files" do
      before :each do
        get "/courses/#{@course.id}/files"
      end
      it "should set usage rights on a file via the modal by clicking the indicator", priority: "1", test_id: 194244 do
        f('.UsageRightsIndicator__openModal').click
        wait_for_ajaximations
        set_usage_rights_in_modal
        react_modal_hidden
        # a11y: focus should go back to the element that was clicked.
        check_element_has_focus(f('.UsageRightsIndicator__openModal'))
        verify_usage_rights_ui_updates
      end
      it "should set usage rights on a file via the cog menu", priority: "1", test_id: 194245 do
        f('.ef-links-col .al-trigger').click
        f('.ItemCog__OpenUsageRights a').click
        wait_for_ajaximations
        set_usage_rights_in_modal
        react_modal_hidden
        # a11y: focus should go back to the element that was clicked.
        check_element_has_focus(f('.ef-links-col .al-trigger'))
        verify_usage_rights_ui_updates
      end
      it "should set usage rights on a file via the toolbar", priority: "1", test_id: 132584 do
        f('.ef-item-row').click
        f('.Toolbar__ManageUsageRights').click
        wait_for_ajaximations
        set_usage_rights_in_modal
        react_modal_hidden
        # a11y: focus should go back to the element that was clicked.
        check_element_has_focus(f('.Toolbar__ManageUsageRights'))
        verify_usage_rights_ui_updates
      end
      it "should set usage rights on a file inside a folder via the toolbar", priority: "1", test_id: 132585 do
        add_folder
        move("a_file.txt", 0, :cog_icon)
        wait_for_ajaximations
        f('.ef-item-row').click
        f('.Toolbar__ManageUsageRights').click
        wait_for_ajaximations
        expect(f('.UsageRightsDialog__fileName').text).to eq "new folder"
        expect(f(".UsageRightsSelectBox__select")).to be_displayed
        set_usage_rights_in_modal
        react_modal_hidden
        # a11y: focus should go back to the element that was clicked.
        check_element_has_focus(f('.Toolbar__ManageUsageRights'))
        ff('.media-body')[0].click
        wait_for_ajaximations
        verify_usage_rights_ui_updates
      end
      it "should not show the creative commons selection if creative commons isn't selected", priority: "1", test_id: 194247 do
        f('.UsageRightsIndicator__openModal').click
        wait_for_ajaximations
        set_value f('.UsageRightsSelectBox__select'), 'fair_use'
        expect(f('.UsageRightsSelectBox__creativeCommons')).to eq(nil)
      end
      it "should publish warning when usage rights is not selected", priority: "2", test_id: 133135 do
        expect(f('.icon-warning')).to be_present
        f('.icon-publish').click
        wait_for_ajaximations
        f('.form-controls .btn-primary').click
        keep_trying_until do
           expect(f('.errorBox')).to be_present
        end
      end
    end

    before :each do
      course_with_teacher_logged_in
      Account.default.enable_feature!(:usage_rights_required)
      add_file(fixture_file_upload('files/a_file.txt', 'text/plan'),
               @course, "a_file.txt")
      add_file(fixture_file_upload('files/amazing_file.txt', 'text/plan'),
               @user, "amazing_file.txt")
      add_file(fixture_file_upload('files/a_file.txt', 'text/plan'),
               @user, "a_file.txt")
    end

    context "user files" do
      it "should update course files from user files page", priority: "1", test_id: 194248 do
        get "/files/folder/courses_#{@course.id}/"
        f('.UsageRightsIndicator__openModal').click
        wait_for_ajaximations
        set_usage_rights_in_modal
        react_modal_hidden
        # a11y: focus should go back to the element that was clicked.
        check_element_has_focus(f('.UsageRightsIndicator__openModal'))
        verify_usage_rights_ui_updates
      end

      it "should copy a file to a different context", priority: "1", test_id: 194249 do
        get "/files/"
        file_name = "amazing_file.txt"
        move(file_name, 1, :cog_icon)
        wait_for_ajaximations
        expect(f("#flash_message_holder").text).to eq "#{file_name} moved to course files\nClose"
        wait_for_ajaximations
        expect(ff('.media-body')[1].text).to eq file_name
      end

      it "should show modal on how to handle duplicates when copying files", priority: "1", test_id: 194250 do
        get "/files/"
        file_name = "a_file.txt"
        move(file_name, 0, :cog_icon)
        wait_for_ajaximations
        expect(f("#renameFileMessage").text).to eq "An item named \"#{file_name}\" already exists in this location. Do you want to replace the existing file?"
        ff(".btn-primary")[2].click
        wait_for_ajaximations
        expect(f("#flash_message_holder").text).to eq "#{file_name} moved to course files\nClose"
        wait_for_ajaximations
        expect(ff('.media-body')[0].text).to eq file_name
      end
    end
  end

end
