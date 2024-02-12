# frozen_string_literal: true

#-- copyright
# OpenProject is an open source project management software.
# Copyright (C) 2012-2024 the OpenProject GmbH
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

module Members
  class RowComponent < ::RowComponent
    property :principal
    delegate :project, to: :table

    def member
      model
    end

    def row_css_id
      "member-#{member.id}"
    end

    def row_css_class
      "member #{principal_class_name} principal-#{principal.id}".strip
    end

    def name
      render Users::AvatarComponent.new(user: principal, size: :mini, link: true, show_name: true)
    end

    def mail
      return unless user?
      return if principal.pref.hide_mail

      link = mail_to(principal.mail)

      if member.principal.invited?
        i = content_tag "i", "", title: t("text_user_invited"), class: "icon icon-mail1"

        link + i
      else
        link
      end
    end

    def roles
      span = content_tag "span", roles_label, id: "member-#{member.id}-roles"

      if can_update?
        span + role_form
      else
        span
      end
    end

    def shared
      count = member.shared_work_packages_count
      if count > 0
        link_to I18n.t(:'label_x_work_packages', count:),
                helpers.project_work_packages_shared_with_path(principal, member.project),
                target: "_blank"
      end
    end

    def roles_label
      project_roles = member.roles.select { |role| role.is_a?(ProjectRole) }.uniq.sort
      label = h project_roles.collect(&:name).join(', ')

      if principal&.admin?
        label << tag(:br) if project_roles.any?
        label << I18n.t(:label_member_all_admin)
      end

      label
    end

    def role_form
      render Members::RoleFormComponent.new(
        member,
        row: self,
        params: controller.params,
        roles: table.available_roles
      )
    end

    def groups
      if user?
        (principal.groups & project.groups).map(&:name).join(", ")
      end
    end

    def status
      helpers.translate_user_status(model.principal.status)
    end

    def can_update? = table.authorize_update && member.project_role?

    def may_delete? = table.authorize_delete

    def deletable_project_role? = member.project_role? && member.deletable?

    def can_delete? = may_delete? && deletable_project_role?

    def may_delete_shares? = table.authorize_work_package_shares_delete

    def has_shared_work_packages? = member.shared_work_packages_count?

    def can_delete_shares? = may_delete_shares? && has_shared_work_packages?

    def actions
      @actions ||= [].tap do |actions|
        actions << edit_action_options if can_update?
        actions << delete_action_options if can_delete? || can_delete_shares?
      end
    end

    def button_links
      return [] if actions.empty?

      if actions.one?
        actions.first => {label:, **button_options}

        [render(Primer::Beta::IconButton.new(**button_options, size: :small, "aria-label": label))]
      else
        [
          render(Primer::Alpha::ActionMenu.new) do |menu|
            menu.with_show_button(scheme: :invisible, size: :small, icon: :'kebab-horizontal', "aria-label": t(:actions))
            actions.each do |action_options|
              action_options => {scheme:, label:, icon:, **button_options}
              menu.with_item(scheme:, label:, content_arguments: button_options) do |item|
                item.with_leading_visual_icon(icon:)
              end
            end
          end
        ]
      end
    end

    def edit_action_options
      {
        scheme: :default,
        icon: :pencil,
        label: t(:button_edit),
        data: {
          action: 'members-form#toggleMembershipEdit',
          members_form_toggling_class_param: toggle_item_class_name,
        },
      }
    end

    def roles_css_id
      "member-#{member.id}-roles"
    end

    def toggle_item_class_name
      "member-#{member.id}--edit-toggle-item"
    end

    def delete_action_options
      dialog = Primer::Alpha::Dialog.new(title: 'Remove member')

      dialog.with_header(variant: :large)

      dialog.with_body do
        case
        when can_delete? && can_delete_shares?
          concat(render(Primer::Beta::Text.new(tag: 'p')) { "This will remove the user’s role from this project. However, #{member.shared_work_packages_count} work packages have also been shared with this user, possibly with different privileges." })
          concat(render(Primer::Beta::Text.new(tag: 'p')) { 'Would you like to keep their access to shared work packages or remove all access?' })
        when can_delete?
          concat(render(Primer::Beta::Text.new(tag: 'p')) { 'Deleting this member will revoke all access privileges of the user to the project.' })
        when can_delete_shares?
          concat(render(Primer::Beta::Text.new(tag: 'p')) { "This user does not have a direct role in this project but #{member.shared_work_packages_count} work packages have been shared with them. This action will revoke their access to all shared work packages." })
        else
          concat(render(Primer::Beta::Text.new(tag: 'p')) { 'You cannot delete this member because they belong to a group that is itself a member of this project.' })
          concat(render(Primer::Beta::Text.new(tag: 'p')) { 'You can either remove the group as a member of the project or this specific member from the group in the administration settings.' })
        end
      end

      dialog.with_footer do
        concat(render(Primer::Beta::Button.new(data: { close_dialog_id: dialog.id })) { "Cancel" })
        case
        when can_delete? && can_delete_shares?
          concat(render(Primer::Beta::Button.new(scheme: :danger, tag: :a, href: delete_url(delete_member: true), data: { method: :delete })) { "Keep only shared" })
          concat(render(Primer::Beta::Button.new(scheme: :danger, tag: :a, href: delete_url(delete_member: true, delete_shared_work_packages: true), data: { method: :delete })) { "Remove all" })
        when can_delete?
          concat(render(Primer::Beta::Button.new(scheme: :danger, tag: :a, href: delete_url(delete_member: true), data: { method: :delete })) { "Remove" })
        when can_delete_shares?
          concat(render(Primer::Beta::Button.new(scheme: :danger, tag: :a, href: delete_url(delete_shared_work_packages: true), data: { method: :delete })) { "Remove" })
        end
      end

      content_for :content_body do
        render(dialog)
      end

      {
        scheme: :danger,
        icon: :trash,
        label: I18n.t(:button_remove),
        data: {
          show_dialog_id: dialog.id,
        },
      }
    end

    def delete_title
      if model.disposable?
        I18n.t(:title_remove_and_delete_user)
      else
        I18n.t(:button_remove)
      end
    end

    def delete_url(delete_member: nil, delete_shared_work_packages: nil)
      url_for(controller: '/members', action: 'destroy_by_principal', principal_id: principal, delete_member:, delete_shared_work_packages:)
    end

    def column_css_class(column)
      if column == :mail
        "email"
      else
        super
      end
    end

    def principal_link
      link_to principal.name, principal_show_path
    end

    def principal_class_name
      principal.model_name.singular
    end

    def principal_show_path
      case principal
      when User
        user_path(principal)
      when Group
        show_group_path(principal)
      else
        placeholder_user_path(principal)
      end
    end

    def user?
      principal.is_a?(User)
    end
  end
end
