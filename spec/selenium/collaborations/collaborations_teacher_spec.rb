# frozen_string_literal: true

#
# Copyright (C) 2015 - present Instructure, Inc.
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

require_relative '../common'
require_relative '../helpers/collaborations_common'
require_relative '../helpers/collaborations_specs_common'
require_relative '../helpers/google_drive_common'

describe "collaborations" do
  include_context "in-process server selenium tests"
  include CollaborationsCommon
  include CollaborationsSpecsCommon
  include GoogleDriveCommon

  context "a teacher's" do
    title = 'Google Docs'
    type = 'google_docs'

    context "#{title} collaboration" do
      before do
        course_with_teacher_logged_in
        setup_google_drive
      end

      it 'is editable', priority: "1" do
        be_editable(type, title)
      end

      it 'is delete-able', priority: "1" do
        be_deletable(type, title)
      end

      it 'displays available collaborators', priority: "1" do
        display_available_collaborators(type)
      end

      it 'start collaboration with people', priority: "1" do
        skip_if_safari(:alert)
        select_collaborators_and_look_for_start(type)
      end
    end

    context "Google Docs collaborations with google docs not having access" do
      before do
        course_with_teacher_logged_in
        setup_google_drive(false, false)
      end

      it 'is not editable if google drive does not have access to your account', priority: "1" do
        no_edit_with_no_access
      end

      it 'is not delete-able if google drive does not have access to your account', priority: "2" do
        no_delete_with_no_access
      end
    end
  end

  describe "Accessibility" do
    before do
      course_with_teacher_logged_in
      create_collaboration!('etherpad', 'Collaboration 1')
      create_collaboration!('etherpad', 'Collaboration 2')

      get "/courses/#{@course.id}/collaborations"
    end

    it 'sets focus to the previous delete icon when deleting an etherpad collaboration' do
      all_icons = ff('.delete_collaboration_link')
      all_icons.last.click
      driver.switch_to.alert.accept
      wait_for_ajaximations
      expect(check_element_has_focus(all_icons.first)).to be
    end

    it 'sets focus to the add collaboration button if there are no previous collaborations' do
      f('.delete_collaboration_link').click
      driver.switch_to.alert.accept
      wait_for_ajaximations
      expect(check_element_has_focus(f('.add_collaboration_link'))).to be
    end
  end
end
