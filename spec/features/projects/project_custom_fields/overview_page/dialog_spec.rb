#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2023 the OpenProject GmbH
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2013 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See COPYRIGHT and LICENSE files for more details.
#++

require 'spec_helper'
require_relative 'shared_context'

RSpec.describe 'Edit project custom fields on project overview page', :js do
  include_context 'with seeded projects, members and project custom fields'

  let(:overview_page) { Pages::Projects::Show.new(project) }

  describe 'with enabled project attributes feature', with_flag: { project_attributes: true } do
    describe 'with insufficient permissions' do
      # TODO: turboframe sidebar request needs to be covered by a controller spec checking for 403
      # TODO: async dialog content request needs to be covered by a controller spec checking for 403
      before do
        login_as member_without_project_edit_permissions
        overview_page.visit_page
      end

      it 'does not show the edit buttons' do
        overview_page.within_async_loaded_sidebar do
          expect(page).to have_no_css("[data-qa-selector='project-custom-field-section-edit-button']")
        end
      end
    end

    describe 'with sufficient permissions' do
      before do
        login_as member_with_project_edit_permissions
        overview_page.visit_page
      end

      it 'shows the edit buttons' do
        overview_page.within_async_loaded_sidebar do
          expect(page).to have_css("[data-qa-selector='project-custom-field-section-edit-button']", count: 3)
        end
      end

      describe 'enables editing of project custom field values via dialog' do
        let(:dialog) { Components::Projects::ProjectCustomFields::EditDialog.new(project, section_for_input_fields) }

        it 'opens a dialog showing inputs for project custom fields of a specific section' do
          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.expect_open
        end

        it 'renders the dialog body asynchronically' do
          expect(page).to have_no_css(dialog.async_content_container_css_selector, visible: :all)

          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          expect(page).to have_css(dialog.async_content_container_css_selector, visible: :visible)
        end

        it 'can be closed via close icon or cancel button' do
          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.close_via_icon

          dialog.expect_closed

          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.close_via_button

          dialog.expect_closed
        end

        it 'shows only the project custom fields of the specific section within the dialog' do
          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.within_async_content(close_after_yield: true) do
            (input_fields + select_fields + multi_select_fields).each do |project_custom_field|
              if input_fields.include?(project_custom_field)
                expect(page).to have_content(project_custom_field.name)
              else
                expect(page).to have_no_content(project_custom_field.name)
              end
            end
          end

          dialog = Components::Projects::ProjectCustomFields::EditDialog.new(project, section_for_select_fields)

          overview_page.open_edit_dialog_for_section(section_for_select_fields)

          dialog.within_async_content(close_after_yield: true) do
            (input_fields + select_fields + multi_select_fields).each do |project_custom_field|
              if select_fields.include?(project_custom_field)
                expect(page).to have_content(project_custom_field.name)
              else
                expect(page).to have_no_content(project_custom_field.name)
              end
            end
          end

          dialog = Components::Projects::ProjectCustomFields::EditDialog.new(project, section_for_multi_select_fields)

          overview_page.open_edit_dialog_for_section(section_for_multi_select_fields)

          dialog.within_async_content(close_after_yield: true) do
            (input_fields + select_fields + multi_select_fields).each do |project_custom_field|
              if multi_select_fields.include?(project_custom_field)
                expect(page).to have_content(project_custom_field.name)
              else
                expect(page).to have_no_content(project_custom_field.name)
              end
            end
          end
        end

        it 'shows the inputs in the correct order defined by the position of project custom field in a section' do
          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.within_async_content(close_after_yield: true) do
            containers = dialog.input_containers

            expect(containers[0].text).to include('Boolean field')
            expect(containers[1].text).to include('String field')
            expect(containers[2].text).to include('Integer field')
            expect(containers[3].text).to include('Float field')
            expect(containers[4].text).to include('Date field')
            expect(containers[5].text).to include('Text field')
          end

          boolean_project_custom_field.move_to_bottom

          overview_page.open_edit_dialog_for_section(section_for_input_fields)

          dialog.within_async_content(close_after_yield: true) do
            containers = dialog.input_containers

            expect(containers[0].text).to include('String field')
            expect(containers[1].text).to include('Integer field')
            expect(containers[2].text).to include('Float field')
            expect(containers[3].text).to include('Date field')
            expect(containers[4].text).to include('Text field')
            expect(containers[5].text).to include('Boolean field')
          end
        end

        describe 'with correct initialization and input behaviour' do
          describe 'with input fields' do
            let(:section) { section_for_input_fields }
            let(:dialog) { Components::Projects::ProjectCustomFields::EditDialog.new(project, section) }

            shared_examples 'a custom field checkbox' do
              it 'shows the correct value if given' do
                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  if expected_initial_value
                    expect(page).to have_checked_field(custom_field.name)
                  else
                    expect(page).to have_no_checked_field(custom_field.name)
                  end
                end
              end

              it 'is unchecked if no value and no default value is given' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_no_checked_field(custom_field.name)
                end
              end

              it 'shows default value if no value is given' do
                custom_field.custom_values.destroy_all

                custom_field.update!(default_value: true)

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_checked_field(custom_field.name)
                end

                custom_field.update!(default_value: false)

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_no_checked_field(custom_field.name)
                end
              end
            end

            shared_examples 'a custom field input' do
              it 'shows the correct value if given' do
                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_field(custom_field.name, with: expected_initial_value)
                end
              end

              it 'shows a blank input if no value or default value is given' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_field(custom_field.name, with: expected_blank_value)
                end
              end

              it 'shows the default value if no value is given' do
                custom_field.custom_values.destroy_all
                custom_field.update!(default_value:)

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  expect(page).to have_field(custom_field.name, with: default_value)
                end
              end
            end

            shared_examples 'a rich text custom field input' do
              it 'shows the correct value if given' do
                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  field.expect_value(expected_initial_value)
                end
              end

              it 'shows a blank input if no value or default value is given' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  field.expect_value(expected_blank_value)
                end
              end

              it 'shows the default value if no value is given' do
                custom_field.custom_values.destroy_all
                custom_field.update!(default_value:)

                overview_page.open_edit_dialog_for_section(section)

                dialog.within_async_content(close_after_yield: true) do
                  field.expect_value(default_value)
                end
              end
            end

            describe 'with boolean CF' do
              let(:custom_field) { boolean_project_custom_field }
              let(:default_value) { false }
              let(:expected_blank_value) { false }
              let(:expected_initial_value) { true }

              it_behaves_like 'a custom field checkbox'
            end

            describe 'with string CF' do
              let(:custom_field) { string_project_custom_field }
              let(:default_value) { 'Default value' }
              let(:expected_blank_value) { '' }
              let(:expected_initial_value) { 'Foo' }

              it_behaves_like 'a custom field input'
            end

            describe 'with integer CF' do
              let(:custom_field) { integer_project_custom_field }
              let(:default_value) { 789 }
              let(:expected_blank_value) { '' }
              let(:expected_initial_value) { 123 }

              it_behaves_like 'a custom field input'
            end

            describe 'with float CF' do
              let(:custom_field) { float_project_custom_field }
              let(:default_value) { 789.123 }
              let(:expected_blank_value) { '' }
              let(:expected_initial_value) { 123.456 }

              it_behaves_like 'a custom field input'
            end

            describe 'with date CF' do
              let(:custom_field) { date_project_custom_field }
              let(:default_value) { Date.new(2026, 1, 1) }
              let(:expected_blank_value) { '' }
              let(:expected_initial_value) { Date.new(2024, 1, 1) }

              it_behaves_like 'a custom field input'
            end

            describe 'with text CF' do
              let(:custom_field) { text_project_custom_field }
              let(:field) { FormFields::Primerized::EditorFormField.new(custom_field) }
              let(:default_value) { 'Default value' }
              let(:expected_blank_value) { '' }
              let(:expected_initial_value) { "Lorem\nipsum" } # TBD: why is the second newline missing?

              it_behaves_like 'a rich text custom field input'
            end
          end

          describe 'with single select fields' do
            let(:section) { section_for_select_fields }
            let(:dialog) { Components::Projects::ProjectCustomFields::EditDialog.new(project, section) }

            shared_examples 'a autocomplete single select field' do
              it 'shows the correct value if given' do
                overview_page.open_edit_dialog_for_section(section)

                field.expect_selected(expected_initial_value)
              end

              it 'shows a blank input if no value or default value is given' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                field.expect_blank
              end

              it 'filters the list based on the input' do
                overview_page.open_edit_dialog_for_section(section)

                field.search(second_option)

                field.expect_option(second_option)
                field.expect_no_option(first_option)
                field.expect_no_option(third_option)
              end

              it 'enables the user to select a single value from a list' do
                overview_page.open_edit_dialog_for_section(section)

                field.search(second_option)
                field.select_option(second_option)

                field.expect_selected(second_option)

                field.search(third_option)
                field.select_option(third_option)

                field.expect_selected(third_option)
                field.expect_not_selected(second_option)
              end

              it 'clears the input if clicked on the clear button' do
                overview_page.open_edit_dialog_for_section(section)

                field.clear

                field.expect_blank
              end
            end

            describe 'with single select list CF' do
              let(:custom_field) { list_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { custom_field.custom_options.first.value }

              let(:first_option) { custom_field.custom_options.first.value }
              let(:second_option) { custom_field.custom_options.second.value }
              let(:third_option) { custom_field.custom_options.third.value }

              it_behaves_like 'a autocomplete single select field'

              it 'shows the default value if no value is given' do
                custom_field.custom_values.destroy_all

                custom_field.custom_options.first.update!(default_value: true)

                overview_page.open_edit_dialog_for_section(section)

                field.expect_selected(custom_field.custom_options.first.value)
              end
            end

            describe 'with single version select list CF' do
              let(:custom_field) { version_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { first_version.name }

              let(:first_option) { first_version.name }
              let(:second_option) { second_version.name }
              let(:third_option) { third_version.name }

              it_behaves_like 'a autocomplete single select field'

              describe 'with correct version scoping' do
                let!(:version_in_other_project) do
                  create(:version, name: 'Version 1 in other project', project: other_project)
                end

                it 'shows only versions that are associated with this project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Version 1')

                  field.expect_option(first_version.name)
                  field.expect_no_option(version_in_other_project.name)
                end
              end
            end

            describe 'with single user select list CF' do
              let(:custom_field) { user_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { member_in_project.name }

              let(:first_option) { member_in_project.name }
              let(:second_option) { another_member_in_project.name }
              let(:third_option) { one_more_member_in_project.name }

              it_behaves_like 'a autocomplete single select field'

              describe 'with correct user scoping' do
                let!(:member_in_other_project) do
                  create(:user,
                         firstname: 'Member 1',
                         lastname: 'In other Project',
                         member_with_roles: { other_project => reader_role })
                end

                it 'shows only users that are members of the project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Member 1')

                  field.expect_option(member_in_project.name)
                  field.expect_no_option(member_in_other_project.name)
                end
              end

              describe 'with support for user groups' do
                let!(:member_in_other_project) do
                  create(:user,
                         firstname: 'Member 1',
                         lastname: 'In other Project',
                         member_with_roles: { other_project => reader_role })
                end
                let!(:group) do
                  create(:group, name: 'Group 1 in project',
                                 member_with_roles: { project => reader_role })
                end
                let!(:group_in_other_project) do
                  create(:group, name: 'Group 1 in other project', members: [member_in_other_project],
                                 member_with_roles: { other_project => reader_role })
                end

                it 'shows only groups that are associated with this project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Group 1')

                  field.expect_option(group.name)
                  field.expect_no_option(group_in_other_project.name)
                end
              end

              describe 'with support for placeholder users' do
                let!(:placeholder_user) do
                  create(:placeholder_user, name: 'Placeholder User',
                                            member_with_roles: { project => reader_role })
                end

                it 'shows the placeholder user' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Placeholder User')

                  field.expect_option(placeholder_user.name)
                end
              end
            end
          end

          describe 'with multi select fields' do
            let(:section) { section_for_multi_select_fields }
            let(:dialog) { Components::Projects::ProjectCustomFields::EditDialog.new(project, section) }

            shared_examples 'a autocomplete multi select field' do
              it 'shows the correct value if given' do
                overview_page.open_edit_dialog_for_section(section)

                field.expect_selected(*expected_initial_value)
              end

              it 'shows a blank input if no value or default value is given' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                field.expect_blank
              end

              it 'filters the list based on the input' do
                overview_page.open_edit_dialog_for_section(section)

                field.search(second_option)

                field.expect_option(second_option)
                field.expect_no_option(first_option)
                field.expect_no_option(third_option)
              end

              it 'allows to select multiple values' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                field.select_option(second_option)
                field.select_option(third_option)

                field.expect_selected(second_option)
                field.expect_selected(third_option)
              end

              it 'allows to remove selected values' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                field.select_option(second_option)
                field.select_option(third_option)

                field.deselect_option(third_option)

                field.expect_selected(second_option)
                field.expect_not_selected(third_option)
              end

              it 'allows to remove all selected values at once' do
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                field.select_option(second_option)
                field.select_option(third_option)

                field.clear

                field.expect_not_selected(second_option)
                field.expect_not_selected(third_option)
              end
            end

            describe 'with multi select list CF' do
              let(:custom_field) { multi_list_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { [custom_field.custom_options.first.value, custom_field.custom_options.second.value] }

              let(:first_option) { custom_field.custom_options.first.value }
              let(:second_option) { custom_field.custom_options.second.value }
              let(:third_option) { custom_field.custom_options.third.value }

              it_behaves_like 'a autocomplete multi select field'

              it 'shows the default value if no value is given' do
                multi_list_project_custom_field.custom_values.destroy_all

                multi_list_project_custom_field.custom_options.first.update!(default_value: true)
                multi_list_project_custom_field.custom_options.second.update!(default_value: true)

                overview_page.open_edit_dialog_for_section(section)

                field.expect_selected(multi_list_project_custom_field.custom_options.first.value)
                field.expect_selected(multi_list_project_custom_field.custom_options.second.value)
              end
            end

            describe 'with multi version select list CF' do
              let(:custom_field) { multi_version_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { [first_version.name, second_version.name] }

              let(:first_option) { first_version.name }
              let(:second_option) { second_version.name }
              let(:third_option) { third_version.name }

              it_behaves_like 'a autocomplete multi select field'

              describe 'with correct version scoping' do
                let!(:version_in_other_project) do
                  create(:version, name: 'Version 1 in other project', project: other_project)
                end

                it 'shows only versions that are associated with this project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Version 1')

                  field.expect_option(first_version.name)
                  field.expect_no_option(version_in_other_project.name)
                end
              end
            end

            describe 'with multi user select list CF' do
              let(:custom_field) { multi_user_project_custom_field }
              let(:field) { FormFields::Primerized::AutocompleteField.new(custom_field) }

              let(:expected_initial_value) { [member_in_project.name, another_member_in_project.name] }

              let(:first_option) { member_in_project.name }
              let(:second_option) { another_member_in_project.name }
              let(:third_option) { one_more_member_in_project.name }

              it_behaves_like 'a autocomplete multi select field'

              describe 'with correct user scoping' do
                let!(:member_in_other_project) do
                  create(:user,
                         firstname: 'Member 1',
                         lastname: 'In other Project',
                         member_with_roles: { other_project => reader_role })
                end

                it 'shows only users that are members of the project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Member 1')

                  field.expect_option(member_in_project.name)
                  field.expect_no_option(member_in_other_project.name)
                end
              end

              describe 'with support for user groups' do
                let!(:member_in_other_project) do
                  create(:user,
                         firstname: 'Member 1',
                         lastname: 'In other Project',
                         member_with_roles: { other_project => reader_role })
                end
                let!(:group) do
                  create(:group, name: 'Group 1 in project',
                                 member_with_roles: { project => reader_role })
                end
                let!(:another_group) do
                  create(:group, name: 'Group 2 in project',
                                 member_with_roles: { project => reader_role })
                end
                let!(:group_in_other_project) do
                  create(:group, name: 'Group 1 in other project', members: [member_in_other_project],
                                 member_with_roles: { other_project => reader_role })
                end

                it 'shows only groups that are associated with this project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Group 1')
                  field.expect_option(group.name)
                  field.expect_no_option(group_in_other_project.name)
                end

                it 'enables to select multiple user groups' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.select_option('Group 1 in project')
                  field.select_option('Group 2 in project')

                  field.expect_selected('Group 1 in project')
                  field.expect_selected('Group 2 in project')
                end
              end

              describe 'with support for placeholder users' do
                let!(:placeholder_user) do
                  create(:placeholder_user, name: 'Placeholder user',
                                            member_with_roles: { project => reader_role })
                end
                let!(:another_placeholder_user) do
                  create(:placeholder_user, name: 'Another placeholder User',
                                            member_with_roles: { project => reader_role })
                end
                let!(:placeholder_user_in_other_project) do
                  create(:placeholder_user, name: 'Placeholder user in other project',
                                            member_with_roles: { other_project => reader_role })
                end

                it 'shows only placeholder users from this project' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.search('Placeholder User')

                  field.expect_option(placeholder_user.name)
                  field.expect_option(another_placeholder_user.name)
                  field.expect_no_option(placeholder_user_in_other_project.name)
                end

                it 'enables to select multiple placeholder users' do
                  overview_page.open_edit_dialog_for_section(section)

                  field.select_option(placeholder_user.name)
                  field.select_option(another_placeholder_user.name)

                  field.expect_selected(placeholder_user.name)
                  field.expect_selected(another_placeholder_user.name)
                end
              end
            end
          end
        end

        describe 'with correct validation behaviour' do
          describe 'with input fields' do
            let(:section) { section_for_input_fields }
            let(:dialog) { Components::Projects::ProjectCustomFields::EditDialog.new(project, section) }

            shared_examples 'a custom field input' do
              it 'shows an error if the value is invalid' do
                custom_field.update!(is_required: true)
                custom_field.custom_values.destroy_all

                overview_page.open_edit_dialog_for_section(section)

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.blank'))
              end
            end

            # boolean CFs can not be validated

            describe 'with string CF' do
              let(:custom_field) { string_project_custom_field }
              let(:field) { FormFields::Primerized::InputField.new(custom_field) }

              it_behaves_like 'a custom field input'

              it 'shows an error if the value is too long' do
                custom_field.update!(max_length: 3)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: 'Foooo')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_long', count: 3))
              end

              it 'shows an error if the value is too short' do
                custom_field.update!(min_length: 3, max_length: 5)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: 'Fo')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_short', count: 3))
              end

              it 'shows an error if the value does not match the regex' do
                custom_field.update!(regexp: '^[A-Z]+$')

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: 'foo')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.invalid'))
              end
            end

            describe 'with integer CF' do
              let(:custom_field) { integer_project_custom_field }
              let(:field) { FormFields::Primerized::InputField.new(custom_field) }

              it_behaves_like 'a custom field input'

              it 'shows an error if the value is too long' do
                custom_field.update!(max_length: 2)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: '111')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_long', count: 2))
              end

              it 'shows an error if the value is too short' do
                custom_field.update!(min_length: 2, max_length: 5)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: '1')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_short', count: 2))
              end
            end

            describe 'with float CF' do
              let(:custom_field) { float_project_custom_field }
              let(:field) { FormFields::Primerized::InputField.new(custom_field) }

              it_behaves_like 'a custom field input'

              it 'shows an error if the value is too long' do
                custom_field.update!(max_length: 4)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: '1111.1')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_long', count: 4))
              end

              it 'shows an error if the value is too short' do
                custom_field.update!(min_length: 4, max_length: 5)

                overview_page.open_edit_dialog_for_section(section)

                field.fill_in(with: '1.1')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_short', count: 4))
              end
            end

            describe 'with date CF' do
              let(:custom_field) { date_project_custom_field }
              let(:field) { FormFields::Primerized::InputField.new(custom_field) }

              it_behaves_like 'a custom field input'
            end

            describe 'with text CF' do
              let(:custom_field) { text_project_custom_field }
              let(:field) { FormFields::Primerized::EditorFormField.new(custom_field) }

              it_behaves_like 'a custom field input'

              it 'shows an error if the value is too long' do
                custom_field.update!(max_length: 3)

                overview_page.open_edit_dialog_for_section(section)

                field.set_value('Foooo')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_long', count: 3))
              end

              it 'shows an error if the value is too short' do
                custom_field.update!(min_length: 3, max_length: 5)

                overview_page.open_edit_dialog_for_section(section)

                field.set_value('Fo')

                dialog.submit

                field.expect_error(I18n.t('activerecord.errors.messages.too_short', count: 3))
              end
            end
          end
        end

        describe 'with correct updating behaviour' do
          # TODO
        end
      end
    end
  end
end