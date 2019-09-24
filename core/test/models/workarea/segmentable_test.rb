require 'test_helper'

module Workarea
  class SegmentableTest < TestCase
    class Foo
      include Mongoid::Document
      include Releasable
      include Segmentable
    end

    def test_active_by_segment
      segment_one = create_segment(name: 'One', position: 1)
      segment_two = create_segment(name: 'Two', position: 2)

      model = Foo.create!(active: false)
      refute(model.active?)

      model.update!(active: true)
      assert(model.active?)

      model.update!(active_by_segment: { segment_one.id => false })
      assert(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { assert(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_by_segment: { segment_two.id => false })
      assert(model.active?)
      Segment.with_current(segment_one) { assert(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_by_segment: { segment_one.id => true, segment_two.id => false })
      assert(model.active?)
      Segment.with_current(segment_one) { assert(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { assert(model.active?) }

      model.update!(active_by_segment: { segment_one.id => false, segment_two.id => true })
      assert(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { assert(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active: false)
      refute(model.active?)

      model.update!(active_by_segment: { segment_one.id => false })
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_by_segment: { segment_two.id => false })
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }

      model.update!(active_by_segment: { segment_one.id => true, segment_two.id => false })
      refute(model.active?)
      Segment.with_current(segment_one) { assert(model.active?) }
      Segment.with_current(segment_two) { refute(model.active?) }
      Segment.with_current(segment_one, segment_two) { assert(model.active?) }

      model.update!(active_by_segment: { segment_one.id => false, segment_two.id => true })
      refute(model.active?)
      Segment.with_current(segment_one) { refute(model.active?) }
      Segment.with_current(segment_two) { assert(model.active?) }
      Segment.with_current(segment_one, segment_two) { refute(model.active?) }
    end

    def test_active_by_segment_typecasting
      segment = create_segment(name: 'One', position: 1)

      model = Foo.create!
      model.update!(active_by_segment: { segment.id => true })
      assert(model.active_by_segment[segment.id.to_s])

      model.update!(active_by_segment: { segment.id => false })
      refute(model.active_by_segment[segment.id.to_s])

      model.update!(active_by_segment: { segment.id => 'true' })
      assert(model.active_by_segment[segment.id.to_s])

      model.update!(active_by_segment: { segment.id => 'false' })
      refute(model.active_by_segment[segment.id.to_s])

      model.update!(active_by_segment: { segment.id => 'true', 'foo' => '' })
      assert(model.active_by_segment[segment.id.to_s])
      refute(model.active_by_segment.key?('foo'))
    end

    def test_assigning_active_by_segment_by_ids
      model = Foo.create!
      model.active_segment_ids = %w(foo bar)
      assert_equal({ 'foo' => true, 'bar' => true }, model.active_by_segment)
      assert_equal(%w(foo bar), model.active_segment_ids)
      assert_equal([], model.inactive_segment_ids)

      model.inactive_segment_ids = %w(bar)
      assert_equal({ 'foo' => true, 'bar' => false }, model.active_by_segment)
      assert_equal(%w(foo), model.active_segment_ids)
      assert_equal(%w(bar), model.inactive_segment_ids)

      model.active_segment_ids = []
      assert_equal({ 'bar' => false }, model.active_by_segment)
      assert_equal([], model.active_segment_ids)
      assert_equal(%w(bar), model.inactive_segment_ids)

      model.inactive_segment_ids = []
      assert_equal({}, model.active_by_segment)
      assert_equal([], model.active_segment_ids)
      assert_equal([], model.inactive_segment_ids)
    end

    def test_segments_and_activate_with
      segment = create_segment
      release = create_release

      model = Foo.create!(activate_with: release.id, active_by_segment: { segment.id => false })
      refute(model.reload.active?)
      assert_equal({}, model.active_by_segment)

      Segment.with_current(segment) do
        refute(model.reload.active?)
        assert_equal({}, model.active_by_segment)

        release.as_current do
          refute(model.reload.active?)
          assert_equal({ segment.id.to_s => false }, model.active_by_segment)
        end
      end

      release.publish!
      assert(model.reload.active?)
      assert_equal({ segment.id.to_s => false }, model.active_by_segment)

      Segment.with_current(segment) { refute(model.reload.active?) }
    end
  end
end
