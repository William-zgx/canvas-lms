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

module RespondusSoapEndpoint
  class Middleware
    class_attribute :servant

    Endpoint = %r{\A/api/respondus/soap}.freeze

    def self.plugin_enabled?
      plugin = Canvas::Plugin.find(:respondus_soap_endpoint)
      plugin.settings[:enabled] == 'true'
    end

    # The first time a call to this API is made, and the plugin is enabled, we
    # call do_setup. This requires the needed SOAP libraries, mixes in the
    # Soap4r::Middleware class, and replaces our call method with the one that
    # actually exposes the SOAP endpoint. Then we return to call, and it calls
    # super to get Soap4r::Middleware's call method that was just mixed in. It's
    # a bit dirty, but we save a lot of memory by not loading all these libraries
    # in processes where this API isn't going to get used, since we don't use
    # soap4r or REXML or any of those anywhere else.
    def self.do_setup
      # an issue with load orders causes us to load the ruby-provided soap4r on
      # some systems, rather than the soap4r gem that we specified (1.5.8). This
      # code ensures that our gem is on the front of the load order, before the
      # system ruby load path.
      # see http://code.google.com/p/phusion-passenger/issues/detail?id=133
      soap_gem_path_idx = $LOAD_PATH.index { |p| p.to_s =~ %r{/soap4r-[\d.]+/lib} }
      if soap_gem_path_idx
        soap_gem_path = $LOAD_PATH.delete_at(soap_gem_path_idx)
        $LOAD_PATH.unshift(soap_gem_path)
      end

      remove_method :call # we'll just use soap4r-middleware's
      Bundler.require 'respondus_soap_endpoint'
      include Soap4r::Middleware
      require 'respondus_soap_endpoint'
      setup do
        self.endpoint = Endpoint
        self.servant = RespondusAPIPort.new
        RespondusAPIPort::Methods.each do |definitions|
          opt = definitions.last
          if opt[:request_style] == :document
            @router.add_document_operation(servant, *definitions)
          else
            @router.add_rpc_operation(servant, *definitions)
          end
        end
        self.mapping_registry = UrnRespondusAPIMappingRegistry::EncodedRegistry
        self.literal_mapping_registry = UrnRespondusAPIMappingRegistry::LiteralRegistry
      end
    end

    def initialize(app)
      @app = app
    end

    def call(env)
      if env['PATH_INFO'].match(Endpoint) && self.class.plugin_enabled?
        self.class.do_setup
        super
      else
        @app.call(env)
      end
    end

    def handle(env)
      servant.rack_env = env
      super(env)
    end
  end
end
