require 'test_helper'

module Workarea
  class SegmentableTest < TestCase
    class Foo
      include Mongoid::Document
      include Releasable
      include Segmentable
    end

    def test_active_by_segment
      segment_one = create_segment(name: 'One')
      segment_two = create_segment(name: 'Two')

      model = Foo.create!(active: false, active_segment_ids: [])
      refute(model.active?)

      model.update!(active: true, active_segment_ids: [])
      assert(model.active?)

      model.update!(active_segment_ids: [segment_one.id])
      assert(model.active?)
      Segment.with_current(segment_one) { assert(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { assert(model.active?) }

      model.update!(active_segment_ids: [segment_two.id])
      assert(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { assert(model.active?) }
      Segment.with_current(segment_one, segment_two) { assert(model.active?) }

      model.update!(active_segment_ids: [segment_one.id, segment_two.id])
      assert(model.active?)
      Segment.with_current(segment_one) { assert(model.active?) }
      Segment.with_current(segment_two) { assert(model.active?) }
      Segment.with_current(segment_one, segment_two) { assert(model.active?) }

      model.update!(active: false, active_segment_ids: [])
      refute(model.active?)

      model.update!(active_segment_ids: [segment_one.id])
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_segment_ids: [segment_two.id])
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_segment_ids: [segment_one.id, segment_two.id])
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }
    end

    def test_segments_and_activate_with
      segment_one = create_segment
      segment_two = create_segment
      release = create_release

      model = Foo.create!(activate_with: release.id, active_segment_ids: [segment_one.id])
      refute(model.reload.active?)

      Segment.with_current(segment_one) do
        refute(model.reload.active?)
        release.as_current { assert(model.reload.active?) }
      end

      Segment.with_current(segment_two) do
        refute(model.reload.active?)
        release.as_current { refute(model.reload.active?) }
      end

      release.publish!
      assert(model.reload.active?)

      Segment.with_current(segment_one) { assert(model.reload.active?) }
      Segment.with_current(segment_two) { refute(model.reload.active?) }
    end
  end
end
