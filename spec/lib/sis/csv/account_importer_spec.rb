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

describe SIS::CSV::AccountImporter do
  before { account_model }

  it 'skips bad content' do
    before_count = Account.where.not(:sis_source_id => nil).count
    importer = process_csv_data(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,active",
      ",,Humanities 3,active",
      "A002,A000,English,active",
      "A003,,English,inactive",
      "A004,,,active"
    )
    expect(Account.where.not(:sis_source_id => nil).count).to eq before_count + 1

    errors = importer.errors.map(&:last)
    expect(errors).to match_array ["No account_id given for an account",
                                   "Parent account didn't exist for A002",
                                   "Improper status \"inactive\" for account A003, skipping",
                                   "No name given for account A004, skipping"]
  end

  it 'creates accounts' do
    before_count = Account.where.not(:sis_source_id => nil).count
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,active",
      "A002,A001,English,active",
      "A003,A002,English Literature,active",
      "A004,,Awesomeness,active"
    )
    expect(Account.where.not(:sis_source_id => nil).count).to eq before_count + 4

    a1 = @account.sub_accounts.where(sis_source_id: 'A001').first
    expect(a1).not_to be_nil
    expect(a1.parent_account_id).to eq @account.id
    expect(a1.root_account_id).to eq @account.id
    expect(a1.name).to eq 'Humanities'

    a2 = a1.sub_accounts.where(sis_source_id: 'A002').first
    expect(a2).not_to be_nil
    expect(a2.parent_account_id).to eq a1.id
    expect(a2.root_account_id).to eq @account.id
    expect(a2.name).to eq 'English'

    a3 = a2.sub_accounts.where(sis_source_id: 'A003').first
    expect(a3).not_to be_nil
    expect(a3.parent_account_id).to eq a2.id
    expect(a3.root_account_id).to eq @account.id
    expect(a3.name).to eq 'English Literature'
  end

  it 'updates the hierarchies of existing accounts' do
    before_count = Account.where.not(:sis_source_id => nil).count
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,active",
      "A002,,English,deleted",
      "A003,,English Literature,active",
      "A004,,Awesomeness,active"
    )
    expect(Account.where.not(:sis_source_id => nil).count).to eq before_count + 4

    %w[A001 A002 A003 A004].each do |id|
      expect(Account.where(sis_source_id: id).first.parent_account).to eq @account
    end
    expect(Account.where(sis_source_id: 'A002').first.workflow_state).to eq "deleted"
    expect(Account.where(sis_source_id: 'A003').first.name).to eq "English Literature"

    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A002,A001,,",
      "A003,A002,,",
      "A004,A002,,"
    )
    expect(Account.where.not(:sis_source_id => nil).count).to eq before_count + 4

    a1 = Account.where(sis_source_id: 'A001').first
    a2 = Account.where(sis_source_id: 'A002').first
    a3 = Account.where(sis_source_id: 'A003').first
    a4 = Account.where(sis_source_id: 'A004').first
    expect(a1.parent_account).to eq @account
    expect(a2.parent_account).to eq a1
    expect(a3.parent_account).to eq a2
    expect(a4.parent_account).to eq a2

    expect(Account.where(sis_source_id: 'A002').first.workflow_state).to eq "deleted"
    expect(Account.where(sis_source_id: 'A003').first.name).to eq "English Literature"
  end

  it 'does not allow deleting accounts with content' do
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,active",
      "A002,A001,Sub Humanities,active"
    )
    importer = process_csv_data(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,deleted"
    )

    errors = importer.errors.map(&:last)
    expect(errors).to eq ["Cannot delete the sub_account with ID: A001 because it has active sub accounts."]
  end

  it 'supports sticky fields' do
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Humanities,active"
    )
    expect(Account.where(sis_source_id: 'A001').first.name).to eq "Humanities"
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Math,active"
    )
    Account.where(sis_source_id: 'A001').first.tap do |a|
      expect(a.name).to eq "Math"
      a.name = "Science"
      a.save!
    end
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,History,active"
    )
    expect(Account.where(sis_source_id: 'A001').first.name).to eq "Science"
  end

  it 'treats parent_account_id as stickyish' do
    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "A001,,Math,active",
      "A002,,Humanities,active",
      "S001,A001,Submath,active",
      { :add_sis_stickiness => true }
    )
    sub = Account.where(sis_source_id: 'S001').first
    expect(sub.reload.parent_account.sis_source_id).to eq "A001"
    expect(sub.stuck_sis_fields).to include(:parent_account_id)

    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "S001,A002,Submath,active"
    )
    expect(sub.reload.parent_account.sis_source_id).to eq "A001" # should not update

    process_csv_data_cleanly(
      "account_id,parent_account_id,name,status",
      "S001,A002,Submath,active",
      { :add_sis_stickiness => true }
    )
    expect(sub.reload.parent_account.sis_source_id).to eq "A002" # should override
  end

  it 'matches headers case-insensitively' do
    before_count = Account.where.not(:sis_source_id => nil).count
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A001,,Humanities,active"
    )
    expect(Account.where.not(:sis_source_id => nil).count).to eq before_count + 1

    a1 = @account.sub_accounts.where(sis_source_id: 'A001').first
    expect(a1).not_to be_nil
    expect(a1.parent_account_id).to eq @account.id
    expect(a1.root_account_id).to eq @account.id
    expect(a1.name).to eq 'Humanities'
  end

  it 'does not allow the creation of loops in account chains' do
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A001,,Humanities,active",
      "A002,A001,Humanities,active"
    )
    importer = process_csv_data(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A001,A002,Humanities,active"
    )
    errors = importer.errors.map(&:last)
    expect(errors).to eq ["Setting account A001's parent to A002 would create a loop"]
  end

  it 'updates batch id on unchanging accounts' do
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A001,,Humanities,active"
    )
    batch = @account.sis_batches.create! { |sb| sb.data = {} }
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A001,,Humanities,active",
      batch: batch
    )
    a1 = @account.sub_accounts.where(sis_source_id: 'A001').first
    expect(a1).not_to be_nil
    expect(a1.sis_batch_id).to eq batch.id
  end

  it 'creates rollback data' do
    batch1 = @account.sis_batches.create! { |sb| sb.data = {} }
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A1,,math,active",
      "A2,A1,special,active",
      batch: batch1
    )
    batch2 = @account.sis_batches.create! { |sb| sb.data = {} }
    process_csv_data_cleanly(
      "Account_ID,Parent_Account_ID,Name,Status",
      "A1,,math,active",
      "A2,A1,special,deleted",
      batch: batch2
    )
    expect(batch1.roll_back_data.where(previous_workflow_state: 'non-existent').count).to eq 2
    expect(batch2.roll_back_data.count).to eq 1
    expect(@account.all_accounts.where(sis_source_id: 'A2').take.workflow_state).to eq 'deleted'
    batch2.restore_states_for_batch
    expect(@account.all_accounts.where(sis_source_id: 'A2').take.workflow_state).to eq 'active'
  end
end
