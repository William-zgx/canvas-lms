# frozen_string_literal: true

#
# Copyright (C) 2014 - present Instructure, Inc.
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

class UsageRights < ActiveRecord::Base
  include ContentLicenses

  USE_JUSTIFICATIONS = %w[own_copyright public_domain used_by_permission fair_use creative_commons].freeze

  belongs_to :context, polymorphic: %i[course group user]

  before_validation :infer_license
  validates :use_justification, inclusion: { in: USE_JUSTIFICATIONS }
  validates :license, inclusion: { in: licenses.keys, allow_nil: true }

  def infer_license
    if license.blank?
      self.license = case use_justification
                     when 'public_domain'
                       'public_domain'
                     when 'creative_commons'
                       'cc_by_nc_nd' # assume the most restrictive CC license unless told otherwise
                     else
                       'private'     # default to private (copyrighted)
                     end
    end
  end

  def license_name
    self.class.licenses[license || 'private'][:readable_license].call
  end

  def license_url
    self.class.licenses[license || 'private'][:license_url]
  end
end
