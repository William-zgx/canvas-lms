# frozen_string_literal: true

#
# Copyright (C) 2020 - present Instructure, Inc.
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

describe NewQuizzesFeaturesHelper do
  include NewQuizzesFeaturesHelper

  before :once do
    course_with_student(active_all: true)
    @context = @course
  end

  describe '#new_quizzes_import_enabled?' do
    it 'is false when new quizzes is disabled' do
      expect(new_quizzes_import_enabled?).to eq false
    end

    it 'is false when new_quizzes enabled, but importing disabled' do
      allow(@context.root_account).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      expect(new_quizzes_import_enabled?).to eq false
    end

    it 'is false when new_quizzes disabled' do
      @context.root_account.enable_feature!(:quizzes_next)
      expect(new_quizzes_import_enabled?).to eq false
    end

    it 'is false when new_quizzes disabled and allowed' do
      allow(@course).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      allow(@course).to receive(:feature_enabled?).with(:quizzes_next).and_return(false)
      expect(new_quizzes_import_enabled?).to eq false
    end

    it 'is true when new_quizzes enabled' do
      allow(@course).to receive(:feature_allowed?).with(:quizzes_next).and_return(false)
      allow(@course).to receive(:feature_enabled?).with(:quizzes_next).and_return(true)
      expect(new_quizzes_import_enabled?).to eq true
    end
  end

  describe '#new_quizzes_migration_enabled?' do
    it 'is false when new quizzes is disabled' do
      expect(new_quizzes_migration_enabled?).to eq false
    end

    it 'is false when new_quizzes enabled, but importing disabled' do
      allow(@context.root_account).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      expect(new_quizzes_migration_enabled?).to eq false
    end

    it 'is false when new_quizzes disabled, but importing enabled' do
      @context.root_account.enable_feature!(:new_quizzes_migration)
      expect(new_quizzes_migration_enabled?).to eq false
    end

    it 'is true when new_quizzes enabled, and importing enabled' do
      allow(@context.root_account).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      @context.root_account.enable_feature!(:new_quizzes_migration)
      expect(new_quizzes_migration_enabled?).to eq true
    end
  end

  describe '#new_quizzes_import_third_party?' do
    it 'is false when new quizzed is disabled' do
      expect(new_quizzes_import_third_party?).to eq false
    end

    it 'is false when new_quizzes enabled, but importing disabled' do
      allow(@context.root_account).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      expect(new_quizzes_import_third_party?).to eq false
    end

    it 'is false when new_quizzes disabled, but importing enabled' do
      @context.root_account.enable_feature!(:new_quizzes_third_party_imports)
      expect(new_quizzes_import_third_party?).to eq false
    end

    it 'is true when new_quizzes enabled, and importing enabled' do
      allow(@context.root_account).to receive(:feature_allowed?).with(:quizzes_next).and_return(true)
      @context.root_account.enable_feature!(:new_quizzes_third_party_imports)
      expect(new_quizzes_import_third_party?).to eq true
    end
  end

  describe "#new_quizzes_migration_default" do
    it 'is false when default is disabled, and migration not required' do
      expect(new_quizzes_migration_default).to eq false
    end

    it 'is true when default is enabled' do
      @context.root_account.enable_feature!(:migrate_to_new_quizzes_by_default)
      expect(new_quizzes_migration_default).to eq true
    end

    it 'is true when migration_required' do
      @context.root_account.enable_feature!(:require_migration_to_new_quizzes)
      expect(new_quizzes_migration_default).to eq true
    end
  end

  describe "#new_quizzes_migration_required" do
    it 'is false when default is disabled, and migration not required' do
      expect(new_quizzes_require_migration?).to eq false
    end

    it 'is true when default is enabled' do
      @context.root_account.enable_feature!(:require_migration_to_new_quizzes)
      expect(new_quizzes_require_migration?).to eq true
    end
  end

  describe "#new_quizzes_navigation_placements_enabled" do
    before do
      allow(@context).to receive(:feature_enabled?).with(:quizzes_next).and_return(true)
      Account.site_admin.enable_feature!(:new_quizzes_account_course_level_item_banks)
    end

    it 'is true when new_quizzes_account_course_level_item_banks and quizzes_next are true' do
      expect(new_quizzes_navigation_placements_enabled?).to eq true
    end

    it 'is false when new_quizzes_account_course_level_item_banks is disabled' do
      Account.site_admin.disable_feature!(:new_quizzes_account_course_level_item_banks)
      expect(new_quizzes_navigation_placements_enabled?).to eq false
    end

    it 'is false when quizzes_next is disabled' do
      allow(@context).to receive(:feature_enabled?).with(:quizzes_next).and_return(false)
      expect(new_quizzes_navigation_placements_enabled?).to eq false
    end

    it 'accepts a context' do
      fake_context = Course.create(name: 'fake context')
      fake_context.disable_feature!(:quizzes_next)
      expect(new_quizzes_navigation_placements_enabled?(fake_context)).to eq false
    end
  end

  describe "#new_quizzes_bank_migrations_enabled?" do
    before do
      allow(@context).to receive(:feature_enabled?).with(:quizzes_next).and_return(true)
      allow(@context.root_account).to receive(:feature_enabled?).with(:new_quizzes_migration).and_return(true)
      Account.site_admin.enable_feature!(:new_quizzes_bank_migrations)
    end

    it 'returns true when new_quizzes_bank_migrations, new_quizzes_migration and quizzes_next are true' do
      expect(new_quizzes_bank_migrations_enabled?).to eq true
    end

    it 'returns false when new_quizzes_bank_migrations is disabled' do
      Account.site_admin.disable_feature!(:new_quizzes_bank_migrations)
      expect(new_quizzes_bank_migrations_enabled?).to eq false
    end

    it 'returns false when quizzes_next is disabled' do
      allow(@context).to receive(:feature_enabled?).with(:quizzes_next).and_return(false)
      expect(new_quizzes_bank_migrations_enabled?).to eq false
    end

    it 'returns false when new_quizzes_migration is disabled' do
      allow(@context.root_account).to receive(:feature_enabled?).with(:new_quizzes_migration).and_return(false)
      expect(new_quizzes_bank_migrations_enabled?).to eq false
    end
  end
end
