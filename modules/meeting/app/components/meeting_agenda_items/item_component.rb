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
  class ItemComponent < Base::TurboComponent

    def initialize(meeting_agenda_item:, active_work_package: nil, state: :initial, **kwargs)
      @meeting_agenda_item = meeting_agenda_item
      @active_work_package = active_work_package
      @state = state
    end

    def wrapper_id
      @meeting_agenda_item.id
    end

    def drag_and_drop_enabled?
      @active_work_package.nil?
    end

    def show_time_slot?
      @active_work_package.nil?
    end

    def edit_enabled?
      if @active_work_package.nil?
        true
      elsif @active_work_package&.id == @meeting_agenda_item.work_package&.id
        true
      else
        false
      end
    end

  end
end