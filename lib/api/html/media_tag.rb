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

require 'nokogiri'

module Api
  module Html
    class MediaTag
      attr_reader :tag, :doc, :node_builder

      def initialize(tag, html, node_builder = Nokogiri::XML::Node)
        @tag = tag
        @doc = html
        @node_builder = node_builder
      end

      def has_media_comment?
        media_id.present?
      end

      # (outgoing) turn anchor tags with media comments into html5 elements
      def as_html5_node(url_helper)
        node_builder.new(media_type, doc).tap do |n|
          n['preload'] = 'none'
          n['class'] = 'instructure_inline_media_comment'
          n['data-media_comment_id'] = media_id
          n['data-media_comment_type'] = media_type
          n['controls'] = 'controls'
          if media_type == 'video'
            n['poster'] = url_helper.media_object_thumbnail_url(media_id)
          end
          n['src'] = url_helper.media_redirect_url(media_id, media_type)
          n['data-alt'] = tag['data-alt']
          n.inner_html = tag.inner_html
          if media_object.present?
            media_object.media_tracks.each do |media_track|
              n << TrackTag.new(media_track, doc, node_builder).to_node(url_helper)
            end
          end
        end
      end

      # (incoming) turn html5 elements into anchor tags with relevant attributes
      def as_anchor_node
        node_builder.new('a', doc).tap do |n|
          if tag_is_an_anchor?
            tag.attributes.each { |k, v| n[k] = v }
            if !already_has_av_comment? && media_object
              n['class'] += " #{media_object.media_type}_comment"
            end
          else
            n['class'] = "instructure_inline_media_comment #{tag.name}_comment"
            n['id'] = "media_comment_#{media_id}"
          end
          n['href'] = "/media_objects/#{media_id}"
        end
      end

      def media_type
        tag['class'].try(:match, /\baudio_comment\b/) ? 'audio' : 'video'
      end

      def media_id
        if tag_is_an_anchor?
          media_comment_regex = /^media_comment_/
          return '' unless tag['id']&.match(media_comment_regex)

          tag['id'].sub(media_comment_regex, '')
        else
          tag['data-media_comment_id']
        end
      end

      private

      def media_object
        @_media_object ||= MediaObject.active.by_media_id(media_id).preload(:media_tracks).first
      end

      def tag_is_an_anchor?
        tag.name == 'a'
      end

      def already_has_av_comment?
        tag['class'] =~ /\b(audio|video)_comment\b/
      end
    end
  end
end
