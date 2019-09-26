require 'test_helper'

module Workarea
  module Storefront
    class SegmentsIntegrationTest < Workarea::IntegrationTest
      include Storefront::IntegrationTest

      def test_life_cycle_segments_functionality
        Workarea.config.loyal_customers_min_orders = 3
        create_life_cycle_segments

        get storefront.current_user_path(format: 'json')
        assert_equal(
          Segment::FirstTimeVisitor.instance.id.to_s,
          response.headers['X-Workarea-Segments']
        )

        cookies[:sessions] = 2
        get storefront.current_user_path(format: 'json')
        assert_equal(
          Segment::ReturningVisitor.instance.id.to_s,
          response.headers['X-Workarea-Segments']
        )

        complete_checkout

        get storefront.current_user_path(format: 'json')
        segments = response.headers['X-Workarea-Segments'].split(',')
        assert_equal(2, segments.size)
        assert_includes(segments, Segment::FirstTimeCustomer.instance.id.to_s)
        assert_includes(segments, Segment::ReturningVisitor.instance.id.to_s)

        complete_checkout

        get storefront.current_user_path(format: 'json')
        segments = response.headers['X-Workarea-Segments'].split(',')
        assert_equal(2, segments.size)
        assert_includes(segments, Segment::ReturningVisitor.instance.id.to_s)
        assert_includes(segments, Segment::ReturningCustomer.instance.id.to_s)

        complete_checkout

        get storefront.current_user_path(format: 'json')
        segments = response.headers['X-Workarea-Segments'].split(',')
        assert_equal(3, segments.size)
        assert_includes(segments, Segment::ReturningVisitor.instance.id.to_s)
        assert_includes(segments, Segment::ReturningCustomer.instance.id.to_s)
        assert_includes(segments, Segment::LoyalCustomer.instance.id.to_s)
      end

      def test_products_active_by_segment
        segment_one = create_segment
        segment_two = create_segment
        product_one = create_product(active: true, active_segment_ids: [segment_two.id])
        product_two = create_product(active: true, active_segment_ids: [segment_one.id])

        get storefront.product_path(product_one)
        assert(response.ok?)

        get storefront.product_path(product_two)
        assert(response.ok?)

        get storefront.search_path(q: '*')
        assert_includes(response.body, product_one.id)
        assert_includes(response.body, product_two.id)

        with_current_segments(segment_one) do
          assert_raise InvalidDisplay do
            get storefront.product_path(product_one)
            assert(response.not_found?)
          end

          get storefront.product_path(product_two)
          assert(response.ok?)

          get storefront.search_path(q: '*')
          refute_includes(response.body, product_one.id)
          assert_includes(response.body, product_two.id)
        end

        with_current_segments(segment_two) do
          get storefront.product_path(product_one)
          assert(response.ok?)

          assert_raise InvalidDisplay do
            get storefront.product_path(product_two)
            assert(response.not_found?)
          end

          get storefront.search_path(q: '*')
          assert_includes(response.body, product_one.id)
          refute_includes(response.body, product_two.id)
        end

        with_current_segments(segment_one, segment_two) do
          get storefront.product_path(product_one)
          assert(response.ok?)

          get storefront.product_path(product_two)
          assert(response.ok?)

          get storefront.search_path(q: '*')
          assert_includes(response.body, product_one.id)
          assert_includes(response.body, product_two.id)
        end
      end

      def test_content_active_by_segment
        segment_one = create_segment
        segment_two = create_segment

        content = Content.for('home_page')
        content.blocks.create!(
          type: 'html',
          data: { 'html' => '<p>Foo</p>' },
          active_segment_ids: [segment_one.id]
        )
        content.blocks.create!(
          type: 'html',
          data: { 'html' => '<p>Bar</p>' },
          active_segment_ids: [segment_two.id]
        )

        with_current_segments(segment_one) do
          get storefront.root_path
          assert_includes(response.body, '<p>Foo</p>')
          refute_includes(response.body, '<p>Bar</p>')
        end

        with_current_segments(segment_two) do
          get storefront.root_path
          refute_includes(response.body, '<p>Foo</p>')
          assert_includes(response.body, '<p>Bar</p>')
        end

        with_current_segments(segment_one, segment_two) do
          get storefront.root_path
          assert_includes(response.body, '<p>Foo</p>')
          assert_includes(response.body, '<p>Bar</p>')
        end
      end

      def test_admins_ignore_segments
        create_life_cycle_segments
        first_time_visitor = Segment::FirstTimeVisitor.instance
        returning_visitor = Segment::ReturningVisitor.instance
        product = create_product(active: true, active_segment_ids: [returning_visitor.id])
        content = Content.for('home_page')
        content.blocks.create!(
          type: 'html',
          data: { 'html' => '<p>Foo</p>' },
          active_segment_ids: [returning_visitor.id]
        )

        set_current_user(create_user(admin: true))

        get storefront.search_path(q: '*')
        assert_includes(response.body, product.id)

        get storefront.root_path
        assert_includes(response.body, '<p>Foo</p>')
      end

      private

      def with_current_segments(*segments)
        Segment.stubs(:current).returns(Segment::Collection.new(*segments))
        yield

      ensure
        Segment.unstub(:current)
      end
    end
  end
end
