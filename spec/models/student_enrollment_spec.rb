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

describe StudentEnrollment do
  before do
    @student = User.create(:name => "some student")
    @course = Course.create(:name => "some course")
    @se = @course.enroll_student(@student)
    @assignment = @course.assignments.create!(:title => 'some assignment')
    @submission = @assignment.submit_homework(@student)
    @assignment.reload
    @course.save!
    @se = @course.student_enrollments.first
  end

  it "belongs to a student" do
    @se.reload
    @student.reload
    expect(@se.user_id).to eql(@student.id)
    expect(@se.user).to eql(@student)
    expect(@se.user.id).to eql(@student.id)
  end

  describe "#update_override_score" do
    let(:course) { @course }
    let(:student) { @student }
    let(:enrollment) { @se }
    let(:teacher) { course.enroll_teacher(User.create!, enrollment_state: "active").user }

    let(:grading_period_group) do
      group = Factories::GradingPeriodGroupHelper.new.create_for_account_with_term(course.account, "test enrollment term")
      now = Time.zone.now
      group.grading_periods.create!(
        title: "a grading period",
        start_date: 1.month.ago(now),
        end_date: 1.month.from_now(now)
      )

      group
    end
    let(:grading_period) { grading_period_group.grading_periods.first }

    let(:grade_change_event) do
      Auditors::ActiveRecord::GradeChangeRecord.find_by(
        context_id: course.id,
        student_id: student.id,
        assignment_id: nil
      )
    end

    before do
      course.enable_feature!(:final_grades_override)
      course.allow_final_grade_override = true
      course.save!

      course.enrollment_term.update!(grading_period_group: grading_period_group)
      course.recompute_student_scores(run_immediately: true)
    end

    it "sets the score for the specific grading period if one is passed in" do
      enrollment.update_override_score(override_score: 80.0, grading_period_id: grading_period.id, updating_user: teacher)
      expect(enrollment.override_score({ grading_period_id: grading_period.id })).to eq 80.0
    end

    it "sets the course score if grading period is nil" do
      enrollment.update_override_score(override_score: 70.0, updating_user: teacher)
      expect(enrollment.override_score).to eq 70.0
    end

    it "emits a grade_override live event" do
      updated_score = enrollment.find_score({ grading_period_id: grading_period.id })

      expect(Canvas::LiveEvents).to receive(:grade_override).with(updated_score, nil, enrollment, course).once
      enrollment.update_override_score(override_score: 70.0, grading_period_id: grading_period.id, updating_user: teacher)
    end

    it "returns the affected score object" do
      score = enrollment.update_override_score(override_score: 80.0, grading_period_id: grading_period.id, updating_user: teacher)
      expect(score).to eq enrollment.find_score({ grading_period_id: grading_period.id })
    end

    it "raises a RecordNotFound error if the score object cannot be found" do
      other_group = Factories::GradingPeriodGroupHelper.new.create_for_account(course.account)
      now = Time.zone.now
      other_period = other_group.grading_periods.create!(
        title: "another grading period",
        start_date: 1.month.from_now(now),
        end_date: 2.months.from_now(now)
      )

      expect do
        enrollment.update_override_score(override_score: 80.0, grading_period_id: other_period.id, updating_user: teacher)
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "records a grade change event if record_grade_change is true and updating_user is supplied" do
      enrollment.update_override_score(
        override_score: 90.0,
        grading_period_id: grading_period.id,
        updating_user: teacher,
        record_grade_change: true
      )

      aggregate_failures do
        expect(grade_change_event).not_to be nil
        expect(grade_change_event.course_id).to eq enrollment.course_id
        expect(grade_change_event.grading_period).to eq grading_period
        expect(grade_change_event.student).to eq student
        expect(grade_change_event.score_after).to eq 90.0
        expect(grade_change_event.grader).to eq teacher
      end
    end

    it "does not record a grade change event if record_grade_change is true but no updating_user is given" do
      enrollment.update_override_score(override_score: 90.0, updating_user: nil, record_grade_change: true)
      expect(grade_change_event).to be nil
    end

    it "does not record a grade change event if record_grade_change is false" do
      enrollment.update_override_score(override_score: 90.0, updating_user: teacher, record_grade_change: false)
      expect(grade_change_event).to be nil
    end

    it "does not record a grade change if the override score did not actually change" do
      enrollment.update_override_score(override_score: 90.0, updating_user: teacher, record_grade_change: true)

      expect do
        enrollment.update_override_score(override_score: 90.0, updating_user: teacher, record_grade_change: true)
      end.not_to change {
        Auditors::ActiveRecord::GradeChangeRecord.where(
          context_id: course.id,
          student_id: student.id,
          assignment_id: nil
        ).count
      }
    end
  end

  describe "pace plan republishing" do
    before :once do
      @enrollment = course_with_student active_all: true
      @pace_plan = @course.pace_plans.create!
      @pace_plan.publish
    end

    it "does nothing if pace plans aren't turned on" do
      @enrollment.update start_at: 1.day.from_now
      expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).not_to exist
    end

    context "with pace plans enabled" do
      before :once do
        @course.enable_pace_plans = true
        @course.save!
      end

      it "queues an update for a new student enrollment" do
        student_in_course(active_all: true, user: user_with_pseudonym)
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).to exist
      end

      it "doesn't queue an update if the pace plan isn't published" do
        @pace_plan.update workflow_state: 'unpublished'
        student_in_course(active_all: true, user: user_with_pseudonym)
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).not_to exist
      end

      it "publishes a student pace plan (alone) if it exists" do
        student_pace_plan = @course.pace_plans.create!(user_id: @enrollment.user_id)
        student_pace_plan.publish
        @enrollment.start_at = 2.days.from_now
        @enrollment.save!
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).not_to exist
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:#{@enrollment.global_user_id}")).to exist
      end

      it "doesn't queue an update for irrelevant changes" do
        @enrollment.last_attended_at = 1.day.ago
        @enrollment.save!
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).not_to exist
      end

      it "queues only one update when multiple enrollments are created" do
        3.times { student_in_course(active_all: true, user: user_with_pseudonym) }
        expect(Delayed::Job.where("strand LIKE 'pace_plan_republish:%'").count).to eq 1
      end

      it "doesn't queue an update for non-student-enrollment creation" do
        ta_in_course(active_all: true, user: user_with_pseudonym)
        expect(Delayed::Job.where(singleton: "pace_plan_republish:#{@course.global_id}:")).not_to exist
      end
    end
  end
end
