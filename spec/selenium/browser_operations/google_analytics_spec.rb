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

require_relative '../common'

describe "google analytics" do
  include_context "in-process server selenium tests"

  it "does not include tracking script if not asked to" do
    get "/"
    wait_for_ajaximations
    expect(f("#content")).not_to contain_jqcss('script[src$="google-analytics.com/analytics.js"]')
  end

  it "includes tracking script if google_analytics_key is configured" do
    Setting.set('google_analytics_key', 'testing123')
    get "/"
    wait_for_ajaximations
    expect(f('script[src$="google-analytics.com/analytics.js"]')).not_to be_nil
  end

  context 'with GA enabled' do
    before do
      Setting.set('google_analytics_key', 'testing123')
    end

    let(:dimensions) do
      {
        admin: { key: 'dimension2', default: '00' },
        enrollments: { key: 'dimension1', default: '000' },
        masquerading: { key: 'dimension3', default: '0' },
        org_type: { key: 'dimension4', default: nil }
      }
    end

    let(:ga_script) do
      driver.execute_script('return arguments[0].innerText',
                            fj('head script:contains(window.ga)'))
    end

    def expect_dimensions_to_include(expected_values)
      dimensions.each do |(dim, spec)|
        expected_value = expected_values.fetch(dim, spec[:default])
        # i shall bear your hatred eternal -- long live the pasta:
        expect(ga_script).to include(
          "ga('set', '#{spec[:key]}', #{expected_value.to_json})" # e.g. ga('set', 'dimension1', false)
        )
      end
    end

    def start_with
      yield if block_given?
      get '/'
      wait_for_ajaximations
    end

    it "includes user roles as dimensions" do
      start_with { nil } # anonymous

      expect_dimensions_to_include({})
    end

    it "includes student status as a dimension" do
      start_with { course_with_student_logged_in }

      expect_dimensions_to_include(enrollments: '100')
    end

    it "includes teacher status as a dimension" do
      start_with { course_with_teacher_logged_in }

      expect_dimensions_to_include(enrollments: '010')
    end

    it "includes observer status as a dimension" do
      start_with { course_with_observer_logged_in }

      expect_dimensions_to_include(enrollments: '001')
    end

    it "includes admin status as a dimension" do
      start_with { admin_logged_in }

      expect_dimensions_to_include(admin: '11')
    end

    it "includes masquerading status as a dimension" do
      start_with do
        admin_logged_in

        masquerade_as(
          user_with_pseudonym(active_all: true).tap do |user|
            course_with_student({
                                  active_course: true,
                                  active_enrollment: true,
                                  user: user,
                                })
          end
        )
      end

      expect_dimensions_to_include(
        admin: '00',
        enrollments: '100',
        masquerading: '1'
      )
    end

    it "identifies the user" do
      start_with { course_with_student_logged_in }

      alternative_user_id = GoogleAnalyticsDimensions.calculate(
        domain_root_account: Account.default,
        real_user: nil,
        user: @student
      ).fetch(:user_id)

      expect(ga_script).to include(
        "ga('set', 'userId', #{alternative_user_id.to_json})"
      )
    end

    it "reports the org type as a dimension" do
      start_with do
        Account.default.external_integration_keys.create!(
          key_type: 'salesforce_org_type',
          key_value: 'K12'
        )
      end

      expect_dimensions_to_include(org_type: 'K12')
    end
  end
end
