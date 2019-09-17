module Workarea
  class SavePublishing
    delegate :errors, to: :release, allow_nil: true

    def initialize(releasable, params)
      @releasable = releasable
      @params = params
    end

    def perform
      return false if release.present? && !release.valid?
      return true if @releasable.blank?

      Release.with_current(release.try(:id)) do
        @releasable.update!(active: activate?, active_by_segment: active_by_segment)
      end
    end

    def release
      return if @params[:activate].in?(%w(now never))

      @release ||=
        if @params[:activate] == 'new_release'
          Release.create(@params[:release])
        else
          Release.find(@params[:activate])
        end
    end

    def activate?
      @params[:activate] != 'never'
    end

    def active_by_segment
      @params[:active_by_segment].to_h
    end
  end
end
