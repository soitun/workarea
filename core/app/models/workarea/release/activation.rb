module Workarea
  class Release
    module Activation
      extend ActiveSupport::Concern

      included do
        around_create :save_activate_with
        attr_accessor :activate_with
      end

      def save_activate_with
        if activate_with?
          self.active = false
          @_active_by_segment = active_by_segment
          self.active_by_segment = {}
        end

        yield
        create_activation_changeset(activate_with) if activate_with?
      end

      def activate_with?
        activate_with.present? && BSON::ObjectId.legal?(activate_with)
      end

      def create_activation_changeset(release_id)
        set = changesets.find_or_initialize_by(release_id: release_id)
        set.document_path = document_path

        # active_by_segment will override activeness, so setting that will need
        # to be part of activation.
        changes = if @_active_by_segment.blank?
          {}
        else
          { active_by_segment: { I18n.locale.to_s => @_active_by_segment } }
        end

        set.changeset = if Workarea.config.localized_active_fields
          changes.merge('active' => { I18n.locale.to_s => true })
        else
          changes.merge('active' => true)
        end

        original = @_active_by_segment.blank? ? {} : { 'active_by_segment' => {} }
        set.original = if Workarea.config.localized_active_fields
          original.merge('active' => { I18n.locale.to_s => false })
        else
          original.merge('active' => false)
        end

        set.save!
      end

      def was_active?
        (Workarea.config.localized_active_fields && active_was[I18n.locale.to_s]) ||
          (!Workarea.config.localized_active_fields && active_was)
      end
    end
  end
end
