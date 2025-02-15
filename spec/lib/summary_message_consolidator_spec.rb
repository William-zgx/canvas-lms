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

describe "SummaryMessageConsolidator" do
  it "processes in batches" do
    Setting.set('summary_message_consolidator_batch_size', '2')
    users = (0..3).map { user_with_communication_channel }
    messages = []
    users.each { |u| 3.times { messages << delayed_message_model(:cc => u.communication_channels.first, :send_at => 1.day.ago) } }

    expects_job_with_tag('Delayed::Batch.serial', 2) do
      SummaryMessageConsolidator.process
    end
    messages.each do |m|
      expect(m.reload.workflow_state).to eq 'sent'
      expect(m.batched_at).to be_present
    end
    queued = created_jobs.map { |j| j.payload_object.jobs.map { |j2| j2.payload_object.args } }.flatten
    expect(queued.map(&:to_i).sort).to eq messages.map(&:id).sort
  end

  it "does not double-send messages" do
    all_messages = []
    u = user_with_communication_channel
    2.times { all_messages << delayed_message_model(:cc => u.communication_channels.first, :send_at => 1.day.ago) }

    allow_any_instance_of(SummaryMessageConsolidator).to receive(:delayed_message_ids_for_batch).and_return(all_messages.map(&:id)) # search grabs all the ids
    already_sent_message, message_to_send = all_messages
    already_sent_message.update_attribute(:workflow_state, "sent") # but one of the messages is already sent
    track_jobs { SummaryMessageConsolidator.process }

    expect(created_jobs.first.payload_object.args.first).to eq [message_to_send.id]
  end

  it "sends summaries from different accounts in separate messages" do
    users = (0..3).map { user_with_communication_channel }
    dms = []
    account_ids = [1, 2, 3]
    delayed_messages_per_account = 2
    account_id_iter = (account_ids * delayed_messages_per_account).sort
    users.each do |u|
      account_id_iter.each do |rai|
        dms << delayed_message_model(
          :cc => u.communication_channels.first,
          :root_account_id => rai,
          :send_at => 1.day.ago
        )
      end
    end

    SummaryMessageConsolidator.process
    dm_summarize_expectation = expect(DelayedMessage).to receive(:summarize)
    dms.each_slice(delayed_messages_per_account) do |slice|
      dm_summarize_expectation.with(slice.map(&:id))
    end
    run_jobs
  end
end
