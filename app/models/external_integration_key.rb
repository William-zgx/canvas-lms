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

class ExternalIntegrationKey < ActiveRecord::Base
  belongs_to :context, polymorphic: [:account]

  validates :context_id, presence: { unless: -> { new_record? && context&.new_record? } }
  validates :context_type, presence: true
  validates :key_type, presence: true
  validates :key_value, presence: true
  validates :key_type, inclusion: { in: proc { key_types } }
  validates :key_type, uniqueness: { scope: [:context_type, :context_id] }

  def key_type
    attributes['key_type'].try(:to_sym)
  end

  scope :of_type, ->(type) { where(key_type: type) }

  def grants_right_for?(user, sought_right)
    rights = self.class.key_type_rights[key_type]
    rights = rights[sought_right] if rights.is_a? Hash
    if rights.respond_to?(:call) && rights.arity == 2
      rights.call(self, user)
    elsif rights.respond_to?(:call) && rights.arity == 0
      rights.call
    else
      rights
    end
  end

  set_policy do
    given { |user| grants_right_for?(user, :read) }
    can :read

    given { |user| grants_right_for?(user, :write) }
    can :write
  end

  class << self
    def indexed_keys_for(context)
      keys = context.external_integration_keys.index_by(&:key_type)
      key_types.each do |key_type|
        next if keys.key?(key_type)

        keys[key_type] = ExternalIntegrationKey.new
        keys[key_type].context = context
        keys[key_type].key_type = key_type
      end
      keys
    end

    def key_type(name, options = {})
      key_types_known << name
      key_type_labels[name] = options[:label]
      key_type_rights[name] = options[:rights] || {}
    end

    def label_for(key_type)
      key_label = key_type_labels[key_type]
      if key_label.respond_to? :call
        key_label.call
      else
        key_label
      end
    end

    def key_types
      key_types_known.to_a
    end

    def key_type_rights
      @key_type_rights ||= {}
    end

    private

    def key_types_known
      @key_types_known ||= Set.new
    end

    def key_type_labels
      @key_type_labels ||= {}
    end
  end
end
