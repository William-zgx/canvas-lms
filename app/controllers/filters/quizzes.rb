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
#

module Filters::Quizzes
  protected

  def require_quiz
    id = params.key?(:quiz_id) ? params[:quiz_id] : params[:id]

    unless (@quiz = @context.quizzes.find(id))
      raise ActiveRecord::RecordNotFound, 'Quiz not found'
    end

    @quiz
  end

  def require_course
    @course = api_find(Course.active, params[:course_id])
    params[:context_id] = params[:course_id]
    params[:context_type] = 'Course'
    authorized_action(@course, @current_user, :read)
  end
end
