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

module MeetingAgendaItems
  class ItemComponent::ShowComponent < ApplicationComponent
    include ApplicationHelper
    include OpPrimer::ComponentHelpers

    def initialize(meeting_agenda_item:)
      super

      @meeting_agenda_item = meeting_agenda_item
    end

    def call
      flex_layout(justify_content: :space_between, align_items: :flex_start) do |flex|
        flex.with_column(flex: 1, flex_layout: true) do |flex|
          if drag_and_drop_enabled?
            flex.with_column(mr: 2) do
              drag_handler_partial
            end
          end
          flex.with_column(flex: 1, mt: 2) do
            description_partial
          end
        end
        flex.with_column do
          right_column_partial
        end
      end
    end

    private

    def right_column_partial
      flex_layout(align_items: :center) do |flex|
        if show_time_slot?
          flex.with_column(pr: 2) do
            time_slot_partial
          end
        end
        if edit_enabled?
          flex.with_column do
            actions_partial
          end
        end
      end
    end

    def drag_and_drop_enabled?
      true
    end

    def drag_handler_partial
      render(Primer::Beta::IconButton.new(
               scheme: :invisible,
               classes: "handle",
               size: :medium,
               disabled: false,
               icon: :grabber,
               show_tooltip: true,
               'aria-label': "Drag agenda item"
             ))
    end

    def show_time_slot?
      true
    end

    def edit_enabled?
      true
    end

    def description_partial
      flex_layout do |flex|
        flex.with_row(mb: 2) do
          title_partial
        end
        flex.with_row do
          # details_partial
        end
      end
    end

    def title_partial
      render(Primer::Beta::Text.new(font_size: :normal, font_weight: :bold)) do
        @meeting_agenda_item.title
      end
    end

    def details_partial
      # render(MeetingAgendaItems::ItemComponent::NotesComponent.new(meeting_agenda_item: @meeting_agenda_item))
    end

    def time_slot_partial
      render(Primer::Beta::Text.new(font_size: :normal, color: :subtle)) do
        [
          @meeting_agenda_item.start_time.strftime("%H:%M"),
          "-",
          @meeting_agenda_item.end_time.strftime("%H:%M"),
          "(#{@meeting_agenda_item.duration_in_minutes || 0} min)"
        ].join(" ")
      end
    end

    def actions_partial
      render(Primer::Alpha::ActionMenu.new) do |menu|
        menu.with_show_button(icon: "kebab-horizontal", 'aria-label': "Agenda item actions")
        edit_action_item(menu)
        delete_action_item(menu)
      end
    end

    def edit_action_item(menu)
      menu.with_item(label: "Edit agenda item",
                     href: edit_meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item),
                     content_arguments: {
                       data: { 'turbo-stream': true }
                     })
    end

    def delete_action_item(menu)
      menu.with_item(label: "Delete agenda item",
                     color: :danger,
                     href: meeting_agenda_item_path(@meeting_agenda_item.meeting, @meeting_agenda_item),
                     form_arguments: {
                       method: :delete, data: { confirm: "Are you sure?", 'turbo-stream': true }
                     })
    end
  end
end
