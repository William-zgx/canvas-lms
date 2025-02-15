# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.

require_relative '../helpers/context_modules_common'
require_relative '../helpers/public_courses_context'

describe "context modules" do
  include_context "in-process server selenium tests"
  include ContextModulesCommon

  context "as a teacher", priority: "1" do
    before(:once) do
      course_with_teacher(active_all: true)
      # have to add quiz and assignment to be able to add them to a new module
      @quiz = @course.assignments.create!(:title => 'quiz assignment', :submission_types => 'online_quiz')
      @assignment = @course.assignments.create!(:title => 'assignment 1', :submission_types => 'online_text_entry')
      @assignment2 = @course.assignments.create!(:title => 'assignment 2',
                                                 :submission_types => 'online_text_entry',
                                                 :due_at => 2.days.from_now,
                                                 :points_possible => 10)
      @assignment3 = @course.assignments.create!(:title => 'assignment 3', :submission_types => 'online_text_entry')

      @ag1 = @course.assignment_groups.create!(:name => "Assignment Group 1")
      @ag2 = @course.assignment_groups.create!(:name => "Assignment Group 2")
      @course.reload
    end

    before do
      user_session(@teacher)
    end

    def module_with_two_items
      modules = create_modules(1, true)
      modules[0].add_item({ id: @assignment.id, type: 'assignment' })
      modules[0].add_item({ id: @assignment2.id, type: 'assignment' })
      get "/courses/#{@course.id}/modules"
      f(".collapse_module_link[aria-controls='context_module_content_#{modules[0].id}']").click
      wait_for_ajaximations
    end

    it "shows all module items", priority: "1" do
      module_with_two_items
      f(".expand_module_link").click
      wait_for_animations
      expect(f('.context_module .content')).to be_displayed
    end

    it "expands/collapses module with 0 items", priority: "2" do
      modules = create_modules(1, true)
      get "/courses/#{@course.id}/modules"
      f(".collapse_module_link[aria-controls='context_module_content_#{modules[0].id}']").click
      expect(f('.icon-mini-arrow-down')).to be_displayed
    end

    it "hides module items", priority: "1" do
      module_with_two_items
      wait_for_animations
      expect(f('.context_module .content')).not_to be_displayed
    end

    it "rearranges child objects in same module", priority: "1" do
      modules = create_modules(1, true)
      # attach 1 assignment to module 1 and 2 assignments to module 2 and add completion reqs
      item1 = modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })
      item2 = modules[0].add_item({ :id => @assignment2.id, :type => 'assignment' })
      get "/courses/#{@course.id}/modules"
      # setting gui drag icons to pass to driver.action.drag_and_drop
      selector1 = "#context_module_item_#{item1.id} .move_item_link"
      selector2 = "#context_module_item_#{item2.id} .move_item_link"
      list_prior_drag = ff("a.title").map(&:text)
      # performs the change position
      js_drag_and_drop(selector2, selector1)
      list_post_drag = ff("a.title").map(&:text)
      expect(list_prior_drag[0]).to eq list_post_drag[1]
      expect(list_prior_drag[1]).to eq list_post_drag[0]
    end

    it "rearranges child object to new module", priority: "1" do
      modules = create_modules(2, true)
      # attach 1 assignment to module 1 and 2 assignments to module 2 and add completion reqs
      item1_mod1 = modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })
      item1_mod2 = modules[1].add_item({ :id => @assignment2.id, :type => 'assignment' })
      get "/courses/#{@course.id}/modules"
      # setting gui drag icons to pass to driver.action.drag_and_drop
      selector1 = "#context_module_item_#{item1_mod1.id} .move_item_link"
      selector2 = "#context_module_item_#{item1_mod2.id} .move_item_link"
      # performs the change position
      js_drag_and_drop(selector2, selector1)
      list_post_drag = ff("a.title").map(&:text)
      # validates the module 1 assignments are in the expected places and that module 2 context_module_items isn't present
      expect(list_post_drag[0]).to eq "assignment 2"
      expect(list_post_drag[1]).to eq "assignment 1"
      expect(f("#content")).not_to contain_css('#context_modules .context_module:last-child .context_module_items .context_module_item')
    end

    it "deletes a module item", priority: "1" do
      get "/courses/#{@course.id}/modules"

      add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      f('.context_module_item .al-trigger').click
      f('.delete_item_link').click
      expect(driver.switch_to.alert).not_to be_nil
      driver.switch_to.alert.accept
      expect(f('.context_module_items')).not_to include_text(@assignment.title)
    end

    it "edits a module item and validate the changes stick", priority: "1" do
      get "/courses/#{@course.id}/modules"

      item_edit_text = "Assignment Edit 1"
      module_item = add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      tag = ContentTag.last
      edit_module_item(module_item) do |edit_form|
        replace_content(edit_form.find_element(:id, 'content_tag_title'), item_edit_text)
      end
      module_item = f("#context_module_item_#{tag.id}")
      expect(module_item).to include_text(item_edit_text)

      get "/courses/#{@course.id}/assignments/#{@assignment.id}"
      expect(f('h1.title').text).to eq item_edit_text

      expect_new_page_load { f('.modules').click }
      expect(f("#context_module_item_#{tag.id} .title").text).to eq item_edit_text
    end

    it "renames all instances of an item" do
      get "/courses/#{@course.id}/modules"

      add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      item2 = add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      edit_module_item(item2) do |edit_form|
        replace_content(edit_form.find_element(:id, 'content_tag_title'), "renamed assignment")
      end
      all_items = ff(".context_module_item.Assignment_#{@assignment.id}")
      expect(all_items.size).to eq 2
      all_items.each { |i| expect(i.find_element(:css, '.title').text).to eq 'renamed assignment' }
      expect(@assignment.reload.title).to eq 'renamed assignment'
      run_jobs
      @assignment.context_module_tags.each { |tag| expect(tag.title).to eq 'renamed assignment' }

      # reload the page and renaming should still work on existing items
      get "/courses/#{@course.id}/modules"
      item3 = add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      edit_module_item(item3) do |edit_form|
        replace_content(edit_form.find_element(:id, 'content_tag_title'), "again")
      end
      all_items = ff(".context_module_item.Assignment_#{@assignment.id}")
      expect(all_items.size).to eq 3
      all_items.each { |i| expect(i.find_element(:css, '.title').text).to eq 'again' }
      expect(@assignment.reload.title).to eq 'again'
      run_jobs
      @assignment.context_module_tags.each { |tag| expect(tag.title).to eq 'again' }
    end

    it "publishes a newly created item", :xbrowser do
      @course.context_modules.create!(name: "Content Page")
      get "/courses/#{@course.id}/modules"
      add_new_module_item('#wiki_pages_select', 'Page', '[ New Page ]', 'New Page Title')

      tag = ContentTag.last
      item = f("#context_module_item_#{tag.id}")
      item.find_element(:css, '.publish-icon').click
      wait_for_ajax_requests

      expect(tag.reload).to be_published
    end

    it "adds the 'with-completion-requirements' class to rows that have requirements" do
      mod = @course.context_modules.create! name: 'TestModule'
      tag = mod.add_item({ :id => @assignment.id, :type => 'assignment' })

      mod.completion_requirements = { tag.id => { :type => 'must_view' } }
      mod.save

      get "/courses/#{@course.id}/modules"

      ig_rows = ff("#context_module_item_#{tag.id} .with-completion-requirements")
      expect(ig_rows).not_to be_empty
    end

    it "adds a new quiz to a module in a specific assignment group" do
      @course.context_modules.create!(name: "Quiz")
      get "/courses/#{@course.id}/modules"

      add_new_module_item('#quizs_select', 'Quiz', '[ New Quiz ]', "New Quiz") do
        click_option("select[name='quiz[assignment_group_id]']", @ag2.name)
      end
      expect(@ag2.assignments.length).to eq 1
      expect(@ag2.assignments.first.title).to eq "New Quiz"
    end

    it "adds a text header to a module", priority: "1" do
      get "/courses/#{@course.id}/modules"
      header_text = 'new header text'
      add_module('Text Header Module')
      f('.ig-header-admin .al-trigger').click
      f('.add_module_item_link').click
      select_module_item('#add_module_item_select', 'Text Header')
      replace_content(f('#sub_header_title'), header_text)
      f('.add_item_button.ui-button').click
      tag = ContentTag.last
      module_item = f("#context_module_item_#{tag.id}")
      expect(module_item).to include_text(header_text)
    end

    it "always shows module contents on empty module", priority: "1" do
      get "/courses/#{@course.id}/modules"
      add_module 'Test module'
      ff(".icon-mini-arrow-down")[0].click
      expect(f('.context_module .content')).to be_displayed
      expect(ff(".icon-mini-arrow-down")[0]).to be_displayed
    end

    it "allows adding an item twice" do
      @course.context_modules.create!(name: "External Tool")
      get "/courses/#{@course.id}/modules"
      tag = add_new_external_item('External Tool', 'www.instructure.com', 'Instructure')
      expect(f("#context_module_item_#{tag.id}")).to have_attribute(:class, "context_external_tool")
      item1 = add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      item2 = add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      expect(item1).not_to eq item2
      expect(@assignment.reload.context_module_tags.size).to eq 2
    end

    it "does not save an invalid external tool", priority: "1" do
      get "/courses/#{@course.id}/modules"

      add_module 'Test module'
      f('.ig-header-admin .al-trigger').click
      f('.add_module_item_link').click
      select_module_item('#add_module_item_select', 'External Tool')
      f('.add_item_button.ui-button').click
      expect(ff('.alert.alert-error').length).to eq 1
      expect(fj('.alert.alert-error:visible').text).to eq "An external tool can't be saved without a URL."
    end

    it "shows the added pre requisites in the header of a module", priority: "1" do
      add_modules_and_set_prerequisites
      get "/courses/#{@course.id}/modules"
      expect(f('.item-group-condensed:nth-of-type(3) .ig-header .prerequisites_message').text)
        .to eq "Prerequisites: #{@module1.name}, #{@module2.name}"
    end

    it "does not have a prerequisites section when creating the first module" do
      get "/courses/#{@course.id}/modules"

      form = new_module_form
      expect(f('.prerequisites_entry', form)).not_to be_displayed
      replace_content(form.find_element(:id, 'context_module_name'), "first")
      submit_form(form)
      wait_for_ajaximations

      form = new_module_form
      expect(f('.prerequisites_entry', form)).to be_displayed
    end

    it "rearranges modules" do
      m1 = @course.context_modules.create!(:name => 'module 1')
      m2 = @course.context_modules.create!(:name => 'module 2')

      get "/courses/#{@course.id}/modules"
      sleep 2 # not sure what we are waiting on but drag and drop will not work, unless we wait

      m1_handle = fj('#context_modules .context_module:first-child .reorder_module_link .icon-drag-handle')
      m2_handle = fj('#context_modules .context_module:last-child .reorder_module_link .icon-drag-handle')
      driver.action.drag_and_drop(m2_handle, m1_handle).perform
      wait_for_ajax_requests

      m1.reload
      expect(m1.position).to eq 2
      m2.reload
      expect(m2.position).to eq 1
    end

    it "validates locking a module item display functionality" do
      get "/courses/#{@course.id}/modules"
      add_form = new_module_form
      lock_check_click
      wait_for_ajaximations
      expect(add_form.find_element(:css, '.unlock_module_at_details')).to be_displayed
      # verify unlock
      lock_check_click
      wait_for_ajaximations
      expect(add_form.find_element(:css, '.unlock_module_at_details')).not_to be_displayed
    end

    it "properly changes indent of an item with arrows" do
      get "/courses/#{@course.id}/modules"

      add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      tag = ContentTag.last

      f("#context_module_item_#{tag.id} .al-trigger").click
      f('.indent_item_link').click
      expect(f("#context_module_item_#{tag.id}")).to have_class('indent_1')
      tag.reload
      expect(tag.indent).to eq 1
    end

    it "properly changes indent of an item from edit dialog" do
      get "/courses/#{@course.id}/modules"

      add_existing_module_item('#assignments_select', 'Assignment', @assignment.title)
      tag = ContentTag.last

      f("#context_module_item_#{tag.id} .al-trigger").click
      f('.edit_item_link').click
      click_option("#content_tag_indent_select", "Indent 1 Level")
      form = f('#edit_item_form')
      form.submit
      wait_for_ajaximations
      expect(f("#context_module_item_#{tag.id}")).to have_class('indent_1')

      tag.reload
      expect(tag.indent).to eq 1
    end

    context "multiple overridden due dates", priority: "2" do
      def create_section_override(section, due_at)
        override = assignment_override_model(:assignment => @assignment)
        override.set = section
        override.override_due_at(due_at)
        override.save!
      end

      it "indicates when course sections have multiple due dates" do
        modules = create_modules(1, true)
        modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })

        cs1 = @course.default_section
        cs2 = @course.course_sections.create!

        create_section_override(cs1, 3.days.from_now)
        create_section_override(cs2, 4.days.from_now)

        get "/courses/#{@course.id}/modules"

        expect(f(".due_date_display").text).to eq "Multiple Due Dates"
      end

      it "does not indicate multiple due dates if the sections' dates are the same" do
        skip("needs to ignore base if all visible sections are overridden")
        modules = create_modules(1, true)
        modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })

        cs1 = @course.default_section
        cs2 = @course.course_sections.create!

        due_at = 3.days.from_now
        create_section_override(cs1, due_at)
        create_section_override(cs2, due_at)

        get "/courses/#{@course.id}/modules"

        expect(f(".due_date_display").text).not_to be_blank
        expect(f(".due_date_display").text).not_to eq "Multiple Due Dates"
      end

      it "uses assignment due date if there is no section override" do
        modules = create_modules(1, true)
        modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })

        cs1 = @course.default_section
        @course.course_sections.create!

        due_at = 3.days.from_now
        create_section_override(cs1, due_at)
        @assignment.due_at = due_at
        @assignment.save!

        get "/courses/#{@course.id}/modules"
        expect(f(".due_date_display").text).not_to be_blank
        expect(f(".due_date_display").text).not_to eq "Multiple Due Dates"
      end

      it "only uses the sections the user is restricted to" do
        skip("needs to ignore base if all visible sections are overridden")
        modules = create_modules(1, true)
        modules[0].add_item({ :id => @assignment.id, :type => 'assignment' })

        cs1 = @course.default_section
        cs2 = @course.course_sections.create!
        cs3 = @course.course_sections.create!

        user_logged_in
        @course.enroll_user(@user, 'TaEnrollment', :section => cs1, :allow_multiple_enrollments => true, :limit_privileges_to_course_section => true).accept!
        @course.enroll_user(@user, 'TaEnrollment', :section => cs2, :allow_multiple_enrollments => true, :limit_privileges_to_course_section => true).accept!

        due_at = 3.days.from_now
        create_section_override(cs1, due_at)
        create_section_override(cs2, due_at)
        create_section_override(cs3, due_at + 1.day) # This override should not matter

        get "/courses/#{@course.id}/modules"

        expect(f(".due_date_display").text).not_to be_blank
        expect(f(".due_date_display").text).not_to eq "Multiple Due Dates"
      end
    end

    it "shows a vdd tooltip summary for assignments with multiple due dates" do
      selector = "li.Assignment_#{@assignment2.id} .due_date_display"
      get "/courses/#{@course.id}/modules"
      add_existing_module_item('#assignments_select', 'Assignment', @assignment2.title)
      expect(f(selector)).not_to include_text "Multiple Due Dates"

      # add a second due date
      new_section = @course.course_sections.create!(:name => 'New Section')
      override = @assignment2.assignment_overrides.build
      override.set = new_section
      override.due_at = Time.zone.now + 1.day
      override.due_at_overridden = true
      override.save!

      get "/courses/#{@course.id}/modules"
      expect(f(selector)).to include_text "Multiple Due Dates"
      driver.action.move_to(f("#{selector} a")).perform
      wait_for_ajaximations

      tooltip = fj('.vdd_tooltip_content:visible')
      expect(tooltip).to include_text 'New Section'
      expect(tooltip).to include_text 'Everyone else'
    end

    it "publishes a file from the modules page", priority: "1" do
      @module = @course.context_modules.create!(:name => "some module")
      @file = @course.attachments.create!(:display_name => "some file", :uploaded_data => default_uploaded_data, :locked => true)
      @tag = @module.add_item({ :id => @file.id, :type => 'attachment' })
      expect(@file.reload).not_to be_published
      get "/courses/#{@course.id}/modules"
      f("[data-id='#{@file.id}'] > button.published-status").click
      ff(".permissions-dialog-form input[name='permissions']")[0].click
      f(".permissions-dialog-form [type='submit']").click
      wait_for_ajaximations
      expect(@file.reload).to be_published
      expect(f("[data-id='#{@file.id}'] > button.published-status")[:title]).to eq("Published")
    end

    it "shows the file publish button on course home" do
      @course.default_view = 'modules'
      @course.save!

      @module = @course.context_modules.create!(:name => "some module")
      @file = @course.attachments.create!(:display_name => "some file", :uploaded_data => default_uploaded_data)
      @tag = @module.add_item({ :id => @file.id, :type => 'attachment' })

      get "/courses/#{@course.id}"
      expect(f(".context_module_item.attachment .icon-publish")).to be_displayed
    end

    it "renders publish buttons in collapsed modules" do
      @module = @course.context_modules.create! name: "collapsed"
      @module.add_item(type: 'assignment', id: @assignment2.id)
      @progression = @module.evaluate_for(@user)
      @progression.collapsed = true
      @progression.save!
      get "/courses/#{@course.id}/modules"
      f('.expand_module_link').click
      expect(f(".context_module_item.assignment .icon-publish")).to be_displayed
    end

    it "adds a discussion item to a module", priority: "1" do
      @course.context_modules.create!(name: "New Module")
      get "/courses/#{@course.id}/modules"
      add_new_module_item('#discussion_topics_select', 'Discussion', '[ New Topic ]', 'New Discussion Title')
      verify_persistence('New Discussion Title')
    end

    it "adds an external url item to a module", priority: "1" do
      @course.context_modules.create!(name: "New Module")
      get "/courses/#{@course.id}/modules"
      add_new_external_item('External URL', 'www.google.com', 'Google')
      expect(fln('Google')).to be_displayed
    end

    it "requires a url for external url items" do
      @course.context_modules.create!(name: "New Module")
      get "/courses/#{@course.id}/modules"
      f('.ig-header-admin .al-trigger').click
      f('.add_module_item_link').click

      click_option('#add_module_item_select', 'external_url', :value)

      title_input = fj('input[name="title"]:visible')
      replace_content(title_input, 'some title')
      scroll_to(f('.add_item_button.ui-button'))
      f('.add_item_button.ui-button').click

      expect(f('.errorBox:not(#error_box_template)')).to be_displayed

      expect(f("#select_context_content_dialog")).to be_displayed
    end

    it "adds an external tool item to a module", priority: "1" do
      @course.context_modules.create!(name: "New Module")
      get "/courses/#{@course.id}/modules"
      add_new_external_item('External Tool', 'www.instructure.com', 'Instructure')
      expect(fln('Instructure')).to be_displayed
      expect(f('span.publish-icon.unpublished.publish-icon-publish > i.icon-unpublish')).to be_displayed
    end

    it "does not render links for subheader type items", priority: "1" do
      mod = @course.context_modules.create! name: 'Test Module'
      tag = mod.add_item(title: 'Example text header', type: 'sub_header')
      get "/courses/#{@course.id}/modules"
      expect(f("#context_module_item_#{tag.id}")).not_to contain_css(".item_link")
      expect(f("#context_module_item_#{tag.id}")).not_to contain_css("a.for-nvda")
    end

    it "renders links for wiki page type items", priority: "1" do
      mod = @course.context_modules.create! name: 'Test Module'
      page = @course.wiki_pages.create title: 'A Page'
      page.workflow_state = 'unpublished'
      page.save!
      tag = mod.add_item({ :id => page.id, :type => 'wiki_page' })
      get "/courses/#{@course.id}/modules"
      expect(f("#context_module_item_#{tag.id}")).to contain_css(".item_link")
      expect(f("#context_module_item_#{tag.id}")).to contain_css("a.for-nvda")
    end

    context "expanding/collapsing modules" do
      before do
        @mod = create_modules(2, true)
        @mod[0].add_item({ id: @assignment.id, type: 'assignment' })
        @mod[1].add_item({ id: @assignment2.id, type: 'assignment' })
        get "/courses/#{@course.id}/modules"
      end

      def assert_collapsed
        expect(f("#context_module_#{@mod[0].id} span.expand_module_link")).to be_displayed
        expect(f("#context_module_#{@mod[0].id} .content")).to_not be_displayed
        expect(f("#context_module_#{@mod[1].id} span.expand_module_link")).to be_displayed
        expect(f("#context_module_#{@mod[1].id} .content")).to_not be_displayed
      end

      def assert_expanded
        expect(f("#context_module_#{@mod[0].id} span.collapse_module_link")).to be_displayed
        expect(f("#context_module_#{@mod[0].id} .content")).to be_displayed
        expect(f("#context_module_#{@mod[1].id} span.collapse_module_link")).to be_displayed
        expect(f("#context_module_#{@mod[1].id} .content")).to be_displayed
      end

      it "displays collapse all button at top of page" do
        button = f("button#expand_collapse_all")
        expect(button).to be_displayed
        expect(button.attribute("data-expand")).to eq("false")
      end

      it "collapses and expand all modules when clicked and persist after refresh" do
        button = f("button#expand_collapse_all")
        button.click
        wait_for_ajaximations
        assert_collapsed
        expect(button.text).to eq("Expand All")
        refresh_page
        assert_collapsed
        button.click
        wait_for_ajaximations
        assert_expanded
        expect(button.text).to eq("Collapse All")
        refresh_page
        assert_expanded
      end

      it "collapses all after collapsing individually" do
        f("#context_module_#{@mod[0].id} span.collapse_module_link").click
        wait_for_ajaximations
        button = f("button#expand_collapse_all")
        button.click
        wait_for_ajaximations
        assert_collapsed
        expect(button.text).to eq("Expand All")
      end
    end
  end
end
