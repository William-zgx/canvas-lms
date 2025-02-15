# frozen_string_literal: true

#
# Copyright (C) 2015 - present Instructure, Inc.
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
require_relative '../helpers/accounts_auth_providers_common'

describe 'account authentication' do
  include_context 'in-process server selenium tests'
  include AuthenticationProvidersCommon

  before do
    course_with_admin_logged_in
  end

  describe 'sso settings' do
    let(:login_handle_name) { f('#sso_settings_login_handle_name') }
    let(:change_password_url) { f('#sso_settings_change_password_url') }
    let(:auth_discovery_url) { f('#sso_settings_auth_discovery_url') }

    it 'saves', priority: "1" do
      add_sso_config
      expect(login_handle_name).to have_value 'login'
      expect(change_password_url).to have_value 'http://test.example.com'
      expect(auth_discovery_url).to have_value 'http://test.example.com'
    end

    it 'updates', priority: "1" do
      add_sso_config
      login_handle_name.clear
      change_password_url.clear
      auth_discovery_url.clear
      f("#edit_sso_settings button[type='submit']").click
      expect(login_handle_name).not_to have_value 'login'
      expect(change_password_url).not_to have_value 'http://test.example.com'
      expect(auth_discovery_url).not_to have_value 'http://test.example.com'
    end
  end

  describe 'identity provider' do
    context 'ldap' do
      let!(:ldap_aac) { AuthenticationProvider::LDAP }

      it 'allows creation of config', priority: "1" do
        add_ldap_config
        keep_trying_until { expect(ldap_aac.active.count).to eq 1 }
        config = ldap_aac.active.last.reload
        expect(config.auth_host).to eq 'host.example.dev'
        expect(config.auth_port).to eq 1
        expect(config.auth_over_tls).to eq 'simple_tls'
        expect(config.auth_base).to eq 'base'
        expect(config.auth_filter).to eq 'filter'
        expect(config.auth_username).to eq 'username'
        expect(config.auth_decrypted_password).to eq 'password'
      end

      it 'allows update of config', priority: "1" do
        add_ldap_config
        suffix = "ldap_#{ldap_aac.active.last.id}"
        ldap_form = f("#edit_#{suffix}")
        ldap_form.find_element(:id, "auth_host_#{suffix}").clear
        ldap_form.find_element(:id, "auth_port_#{suffix}").clear
        f("label[for=simple_tls_#{suffix}]").click
        ldap_form.find_element(:id, "auth_base_#{suffix}").clear
        ldap_form.find_element(:id, "auth_filter_#{suffix}").clear
        ldap_form.find_element(:id, "auth_username_#{suffix}").clear
        ldap_form.find_element(:id, "auth_password_#{suffix}").send_keys('newpassword')
        ldap_form.find("button[type='submit']").click
        wait_for_ajax_requests

        config = ldap_aac.active.last.reload
        expect(ldap_aac.active.count).to eq 1
        expect(config.auth_host).to eq ''
        expect(config.auth_port).to eq nil
        expect(config.auth_over_tls).to eq 'simple_tls'
        expect(config.auth_base).to eq ''
        expect(config.auth_filter).to eq ''
        expect(config.auth_username).to eq ''
        expect(config.auth_decrypted_password).to eq 'newpassword'
      end

      it 'allows deletion of config', priority: "1" do
        skip_if_safari(:alert)
        add_ldap_config
        f("#delete-aac-#{ldap_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(ldap_aac.active.count).to eq 0
      end

      it 'allows creation of multiple configs', priority: "2" do
        add_ldap_config(1)
        expect(error_displayed?).to be_falsey
        add_ldap_config(2)
        expect(error_displayed?).to be_falsey
      end

      it 'allows deletion of multiple configs', priority: "2" do
        skip_if_safari(:alert)
        add_ldap_config(1)
        add_ldap_config(2)
        keep_trying_until { expect(ldap_aac.active.count).to eq 2 }
        f('.delete_auth_link').click
        expect(alert_present?).to be_truthy
        accept_alert
        wait_for_ajax_requests

        expect(ldap_aac.active.count).to eq 0
        expect(ldap_aac.count).to eq 2
      end
    end

    context 'saml' do
      let!(:saml_aac) { AuthenticationProvider::SAML }

      it 'allows creation of config', priority: "1" do
        add_saml_config
        expect { saml_aac.active.count }.to become 1
        config = saml_aac.active.last.reload
        expect(config.idp_entity_id).to eq 'entity.example'
        expect(config.log_in_url).to eq 'login.example'
        expect(config.log_out_url).to eq 'logout.example'
        expect(config.certificate_fingerprint).to eq 'abc123'
        expect(config.login_attribute).to eq 'NameID'
        expect(config.identifier_format).to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
        expect(config.requested_authn_context).to eq nil
        expect(config.parent_registration).to be_falsey
      end

      it 'allows update of config', priority: "1" do
        add_saml_config
        expect { saml_aac.active.count }.to become 1
        suffix = "saml_#{saml_aac.active.last.id}"
        saml_form = f("#edit_#{suffix}")
        f("#idp_entity_id_#{suffix}").clear
        f("#log_in_url_#{suffix}").clear
        f("#log_out_url_#{suffix}").clear
        f("#certificate_fingerprint_#{suffix}").clear
        saml_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(saml_aac.active.count).to eq 1
        config = saml_aac.active.last.reload
        expect(config.idp_entity_id).to eq ''
        expect(config.log_in_url).to eq ''
        expect(config.log_out_url).to eq ''
        expect(config.certificate_fingerprint).to eq ''
        expect(config.login_attribute).to eq 'NameID'
        expect(config.identifier_format).to eq 'urn:oasis:names:tc:SAML:1.1:nameid-format:unspecified'
        expect(config.requested_authn_context).to eq nil
        expect(config.parent_registration).to be_falsey
      end

      it 'allows deletion of config', priority: "1" do
        skip_if_safari(:alert)
        add_saml_config
        expect { saml_aac.active.count }.to become 1
        f("#delete-aac-#{saml_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(saml_aac.active.count).to eq 0
        expect(saml_aac.count).to eq 1
      end

      context 'debugging' do
        it 'starts debug info', priority: "1" do
          enable_cache do
            start_saml_debug
            wait_for_ajaximations

            debug_info = f(".debug_data")
            expect(debug_info.text).to match('Waiting for attempted login')
          end
        end

        it 'refreshes debug info', priority: "1" do
          enable_cache do
            start_saml_debug
            wait_for_ajaximations

            aac = Account.default.authentication_providers.active.last
            aac.class.debugging_keys.map(&:keys).flatten.each_with_index do |key, i|
              aac.debug_set(key, "testvalue#{i}")
            end

            refresh = f(".refresh_debugging")
            refresh.click
            wait_for_ajaximations

            debug_info = f(".debug_data")

            aac.class.debugging_keys.map(&:keys).flatten.each_with_index do |_, i|
              expect(debug_info.text).to match("testvalue#{i}")
            end
          end
        end

        it 'stops debug info', priority: "1" do
          enable_cache do
            start_saml_debug
            wait_for_ajaximations

            stop = f(".stop_debugging")

            stop.click
            wait_for_ajaximations

            aac = Account.default.authentication_providers.active.last
            expect(aac.debugging?).to eq false

            aac.class.debugging_keys.map(&:keys).flatten.each do |key|
              expect(aac.debug_get(key)).to eq nil
            end
          end
        end
      end

      context 'federated attributes' do
        let!(:ap) do
          Account.default.authentication_providers.create!(auth_type: 'saml')
        end

        it 'saves federated attributes' do
          get "/accounts/self/authentication_providers"
          click_option("select.canvas_attribute", "locale")
          f(".add_federated_attribute_button").click
          f("input[name='authentication_provider[federated_attributes][locale][attribute]']").send_keys("provider_locale")
          saml_form = f("#edit_saml_#{ap.id}")
          expect_new_page_load do
            saml_form.find("button[type='submit']").click
          end

          ap.reload
          expect(ap.federated_attributes).to eq({ 'locale' => { 'attribute' => 'provider_locale',
                                                                'provisioning_only' => false } })
          expect(f("input[name='authentication_provider[federated_attributes][locale][attribute]']")[:value]).to eq 'provider_locale'
        end

        it 'shows and saves provisioning only checkboxes' do
          get "/accounts/self/authentication_providers"
          click_option("select.canvas_attribute", "locale")
          f(".add_federated_attribute_button").click
          f("input[name='authentication_provider[federated_attributes][locale][attribute]']").send_keys("provider_locale")
          f('.jit_provisioning_checkbox').click
          provisioning_only = f("input[name='authentication_provider[federated_attributes][locale][provisioning_only]']")
          expect(provisioning_only).to be_displayed
          provisioning_only.click

          saml_form = f("#edit_saml_#{ap.id}")
          expect_new_page_load do
            saml_form.find("button[type='submit']").click
          end

          ap.reload
          expect(ap.federated_attributes).to eq({ 'locale' => { 'attribute' => 'provider_locale',
                                                                'provisioning_only' => true } })
          expect(f("input[name='authentication_provider[federated_attributes][locale][attribute]']").attribute('value')).to eq 'provider_locale'
          expect(is_checked("input[name='authentication_provider[federated_attributes][locale][provisioning_only]']:visible")).to eq true
        end

        it 'hides provisioning only when jit provisioning is disabled' do
          ap.update_attribute(:federated_attributes, { 'locale' => 'provider_locale' })
          ap.update_attribute(:jit_provisioning, true)
          get "/accounts/self/authentication_providers"

          provisioning_only = "input[name='authentication_provider[federated_attributes][locale][provisioning_only]']"
          expect(f(provisioning_only)).to be_displayed
          f('.jit_provisioning_checkbox').click
          expect(f(provisioning_only)).not_to be_displayed
        end

        it 'clears provisioning only when toggling jit provisioning' do
          get "/accounts/self/authentication_providers"
          click_option("select.canvas_attribute", "locale")
          f(".add_federated_attribute_button").click
          f("input[name='authentication_provider[federated_attributes][locale][attribute]']").send_keys("provider_locale")
          f('.jit_provisioning_checkbox').click
          provisioning_only = "input[name='authentication_provider[federated_attributes][locale][provisioning_only]']"
          expect(f(provisioning_only)).to be_displayed
          f(provisioning_only).click
          expect(is_checked("input[name='authentication_provider[federated_attributes][locale][provisioning_only]']:visible")).to eq true
          f('.jit_provisioning_checkbox').click
          f('.jit_provisioning_checkbox').click
          expect(is_checked("input[name='authentication_provider[federated_attributes][locale][provisioning_only]']:visible")).to eq false
        end

        it 'hides the add attributes button when all are added' do
          get "/accounts/self/authentication_providers"
          AuthenticationProvider::CANVAS_ALLOWED_FEDERATED_ATTRIBUTES.length.times do
            f(".add_federated_attribute_button").click
          end
          expect(f(".add_federated_attribute_button")).not_to be_displayed

          fj(".remove_federated_attribute:visible").click
          expect(f(".add_federated_attribute_button")).to be_displayed
          expect(ffj("select.canvas_attribute:visible option").length).to eq 1
        end

        it 'can remove all attributes' do
          ap.update_attribute(:federated_attributes, { 'locale' => 'provider_locale' })
          get "/accounts/self/authentication_providers"

          fj(".remove_federated_attribute:visible").click
          saml_form = f("#edit_saml_#{ap.id}")
          expect_new_page_load do
            saml_form.find("button[type='submit']").click
          end

          expect(ap.reload.federated_attributes).to eq({})
        end

        it "doesn't include screenreader text when removing attributes" do
          ap.update_attribute(:federated_attributes, { 'locale' => 'provider_locale' })
          get "/accounts/self/authentication_providers"

          f(".add_federated_attribute_button").click
          # remove an attribute that was already on the page, and one that was dynamically added
          2.times do
            fj(".remove_federated_attribute:visible").click
          end
          available = ff("#edit_saml_#{ap.id} .federated_attributes_select option")
          expect(available.any? { |attr| attr.text =~ /attribute/i }).to eq false
        end
      end
    end

    context 'cas' do
      let!(:cas_aac) { AuthenticationProvider::CAS }

      it 'allows creation of config', priority: "1" do
        add_cas_config
        keep_trying_until { expect(cas_aac.active.count).to eq 1 }
        config = cas_aac.active.last.reload
        expect(config.auth_base).to eq 'http://auth.base.dev'
      end

      it 'allows update of config', priority: "1" do
        add_cas_config
        suffix = "cas_#{cas_aac.active.last.id}"
        cas_form = f("#edit_#{suffix}")
        cas_form.find("#auth_base_#{suffix}").clear
        cas_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(cas_aac.active.count).to eq 1
        config = cas_aac.active.last.reload
        expect(config.auth_base).to eq ''
      end

      it 'allows deletion of config', priority: "1" do
        skip_if_safari(:alert)
        add_cas_config
        f("#delete-aac-#{cas_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(cas_aac.active.count).to eq 0
        expect(cas_aac.count).to eq 1
      end
    end

    context 'facebook' do
      let!(:facebook_aac) { AuthenticationProvider::Facebook }

      it 'allows creation of config', priority: "2" do
        add_facebook_config
        keep_trying_until { expect(facebook_aac.active.count).to eq 1 }
        config = facebook_aac.active.last.reload
        expect(config.entity_id).to eq '123'
        expect(config.login_attribute).to eq 'id'
      end

      it 'allows update of config', priority: "2" do
        add_facebook_config
        suffix = "facebook_#{facebook_aac.active.last.id}"
        facebook_form = f("#edit_#{suffix}")
        f("#app_id_#{suffix}").clear
        facebook_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(facebook_aac.active.count).to eq 1
        config = facebook_aac.active.last.reload
        expect(config.entity_id).to eq ''
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_facebook_config
        f("#delete-aac-#{facebook_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(facebook_aac.active.count).to eq 0
        expect(facebook_aac.count).to eq 1
      end
    end

    context 'github' do
      let!(:github_aac) { AuthenticationProvider::GitHub }

      it 'allows creation of config', priority: "2" do
        add_github_config
        keep_trying_until { expect(github_aac.active.count).to eq 1 }
        config = github_aac.active.last.reload
        expect(config.auth_host).to eq 'github.com'
        expect(config.entity_id).to eq '1234'
        expect(config.login_attribute).to eq 'id'
      end

      it 'allows update of config', priority: "2" do
        add_github_config
        suffix = "github_#{github_aac.active.last.id}"
        github_form = f("#edit_#{suffix}")
        github_form.find_element(:id, "domain_#{suffix}").clear
        github_form.find_element(:id, "client_id_#{suffix}").clear
        github_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(github_aac.active.count).to eq 1
        config = github_aac.active.last.reload
        expect(config.auth_host).to eq ''
        expect(config.entity_id).to eq ''
        expect(config.login_attribute).to eq 'id'
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_github_config
        f("#delete-aac-#{github_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(github_aac.active.count).to eq 0
        expect(github_aac.count).to eq 1
      end
    end

    context 'google' do
      let!(:google_aac) { AuthenticationProvider::Google }

      it 'allows creation of config', priority: "2" do
        add_google_config
        keep_trying_until { expect(google_aac.active.count).to eq 1 }
        config = google_aac.active.last.reload
        expect(config.entity_id).to eq '1234'
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows update of config', priority: "2" do
        add_google_config
        suffix = "google_#{google_aac.active.last.id}"
        google_form = f("#edit_#{suffix}")
        google_form.find_element(:id, "client_id_#{suffix}").clear
        google_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(google_aac.active.count).to eq 1
        config = google_aac.active.last.reload
        expect(config.entity_id).to eq ''
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_google_config
        f("#delete-aac-#{google_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(google_aac.active.count).to eq 0
        expect(google_aac.count).to eq 1
      end
    end

    context 'linkedin' do
      let!(:linkedin_aac) { AuthenticationProvider::LinkedIn }

      it 'allows creation of config', priority: "2" do
        add_linkedin_config
        keep_trying_until { expect(linkedin_aac.active.count).to eq 1 }
        config = linkedin_aac.active.last.reload
        expect(config.entity_id).to eq '1234'
        expect(config.login_attribute).to eq 'id'
      end

      it 'allows update of config', priority: "2" do
        add_linkedin_config
        suffix = "linkedin_#{linkedin_aac.active.last.id}"
        linkedin_form = f("#edit_#{suffix}")
        linkedin_form.find_element(:id, "client_id_#{suffix}").clear
        linkedin_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(linkedin_aac.active.count).to eq 1
        config = linkedin_aac.active.last.reload
        expect(config.entity_id).to eq ''
        expect(config.login_attribute).to eq 'id'
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_linkedin_config
        f("#delete-aac-#{linkedin_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(linkedin_aac.active.count).to eq 0
        expect(linkedin_aac.count).to eq 1
      end
    end

    context 'openid connect' do
      let!(:openid_aac) { AuthenticationProvider::OpenIDConnect }

      it 'allows creation of config', priority: "2" do
        add_openid_connect_config
        keep_trying_until { expect(openid_aac.active.count).to eq 1 }
        config = openid_aac.active.last.reload
        expect(config.entity_id).to eq '1234'
        expect(config.log_in_url).to eq 'http://authorize.url.dev'
        expect(config.auth_base).to eq 'http://token.url.dev'
        expect(config.requested_authn_context).to eq 'scope'
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows update of config', priority: "2" do
        add_openid_connect_config
        suffix = "openid_connect_#{openid_aac.active.last.id}"
        openid_connect_form = f("#edit_#{suffix}")
        openid_connect_form.find_element(:id, "client_id_#{suffix}").clear
        f("#authorize_url_#{suffix}").clear
        f("#token_url_#{suffix}").clear
        f("#scope_#{suffix}").clear
        openid_connect_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(openid_aac.active.count).to eq 1
        config = openid_aac.active.last.reload
        expect(config.entity_id).to eq ''
        expect(config.log_in_url).to eq ''
        expect(config.auth_base).to eq ''
        expect(config.requested_authn_context).to eq ''
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_openid_connect_config
        f("#delete-aac-#{openid_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(openid_aac.active.count).to eq 0
        expect(openid_aac.count).to eq 1
      end
    end

    context 'twitter' do
      let!(:twitter_aac) { AuthenticationProvider::Twitter }

      it 'allows creation of config', priority: "2" do
        add_twitter_config
        keep_trying_until { expect(twitter_aac.active.count).to eq 1 }
        config = twitter_aac.active.last.reload
        expect(config.entity_id).to eq '1234'
        expect(config.login_attribute).to eq 'user_id'
      end

      it 'allows update of config', priority: "2" do
        add_twitter_config
        suffix = "twitter_#{twitter_aac.active.last.id}"
        twitter_form = f("#edit_#{suffix}")
        twitter_form.find_element(:id, "consumer_key_#{suffix}").clear
        twitter_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(twitter_aac.active.count).to eq 1
        config = twitter_aac.active.last.reload
        expect(config.entity_id).to eq ''
        expect(config.login_attribute).to eq 'user_id'
      end

      it 'allows deletion of config', priority: "2" do
        skip_if_safari(:alert)
        add_twitter_config
        f("#delete-aac-#{twitter_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(twitter_aac.active.count).to eq 0
        expect(twitter_aac.count).to eq 1
      end
    end

    context 'microsoft' do
      let!(:microsoft_aac) { AuthenticationProvider::Microsoft }

      it 'allows creation of config', priority: "2" do
        expect(microsoft_aac.active.count).to eq 0
        add_microsoft_config
        keep_trying_until { expect(microsoft_aac.active.count).to eq 1 }
        config = microsoft_aac.active.last.reload
        expect(config.entity_id).to eq '1234'
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows update of config', priority: "2" do
        add_microsoft_config
        suffix = "microsoft_#{microsoft_aac.active.last.id}"
        microsoft_form = f("#edit_#{suffix}")
        microsoft_form.find_element(:id, "application_id_#{suffix}").clear
        microsoft_form.find("button[type='submit']").click
        wait_for_ajax_requests

        expect(microsoft_aac.active.count).to eq 1
        config = microsoft_aac.active.last.reload
        expect(config.entity_id).to eq ''
        expect(config.login_attribute).to eq 'sub'
      end

      it 'allows deletion of config', priority: "2" do
        add_microsoft_config
        f("#delete-aac-#{microsoft_aac.active.last.id}").click
        accept_alert
        wait_for_ajax_requests

        expect(microsoft_aac.active.count).to eq 0
        expect(microsoft_aac.count).to eq 1
      end
    end
  end
end
