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
class OverviewPage
  include Rails.application.routes.url_helpers
  include Capybara::DSL
  include Capybara::RSpecMatchers
  include RSpec::Matchers

  def initialize(project)
    @project = project
  end

  def visit_page
    visit project_path(@project.id)
  end

  def within_async_loaded_sidebar
    within '#project-attributes-sidebar' do
      expect(page).to have_css("[data-qa-selector='project-attributes-sidebar-async-content']")
      yield
    end
  end

  def within_custom_field_section_container(section, &)
    within("[data-qa-selector='project-custom-field-section-#{section.id}']", &)
  end

  def within_custom_field_container(custom_field, &)
    within("[data-qa-selector='project-custom-field-#{custom_field.id}']", &)
  end

  def open_edit_dialog_for_section(section)
    within_async_loaded_sidebar do
      within_custom_field_section_container(section) do
        page.find("[data-qa-selector='project-custom-field-section-edit-button']").click
      end
    end
  end

  def close_edit_dialog_for_section(section)
    within("modal-dialog#edit-project-attributes-dialog-#{section.id}") do
      page.find(".close-button").click
    end
  end

  def within_edit_dialog_for_section(section, &)
    within("modal-dialog#edit-project-attributes-dialog-#{section.id}", &)
  end
end