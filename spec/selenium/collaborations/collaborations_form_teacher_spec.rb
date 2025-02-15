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

      it 'displays the new collaboration form if there are no existing collaborations', priority: "1" do
        # was tied to test_id: 162302 - this seems incorrect.
        new_collaborations_form(type)
      end

      it 'does not display the new collaboration form if other collaborations exist', priority: "1" do
        not_display_new_form_if_none_exist(type, title)
      end

      it 'opens the new collaboration form if the last collaboration is deleted', priority: "1" do
        open_form_if_last_was_deleted(type, title)
      end

      it 'does not display the new collaboration form when the penultimate collaboration is deleted', priority: "1" do
        not_display_new_form_when_penultimate_collaboration_is_deleted(type, title)
      end

      it 'leaves the new collaboration form open when the last collaboration is deleted', priority: "1" do
        leave_new_form_open_when_last_is_deleted(type, title)
      end

      it 'selects collaborators', priority: "1" do
        select_collaborators(type)
      end

      it "does not show inactive students in list" do
        ensure_plugin(type)

        student_in_course(:course => @course)
        @student.update_attribute(:name, 'real user')

        enrollment = student_in_course(:course => @course)
        @student.update_attribute(:name, 'inactive user')
        enrollment.deactivate

        get "/courses/#{@course.id}/collaborations"

        expect(ff('.available-users li').length).to eq 2
        expect(f('.available-users')).to_not include_text("inactive")
      end

      it 'selects from all course groups', priority: "1" do
        select_from_all_course_groups(type, title)
      end

      it 'deselects collaborators', priority: "1" do
        deselect_collaborators(type)
      end

      context '#add_collaboration fragment' do
        it 'displays the new collaboration form if no collaborations exist', priority: "2" do
          display_new_form_if_none_exist(type)
        end

        it 'hides the new collaboration form if collaborations exist', priority: "2" do
          hide_new_form_if_exists(type, title)
        end
      end
    end
  end
end
