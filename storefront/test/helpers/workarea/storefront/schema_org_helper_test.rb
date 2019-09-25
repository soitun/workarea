require 'test_helper'

module Workarea
  module Storefront
    class SchemaOrgHelperTest < ViewTest
      include Storefront::Engine.routes.url_helpers
      include NavigationHelper

      def test_breadcrumb_url_for
        product = create_product
        page = create_page
        url_taxon = create_taxon(url: 'https://www.example.com')
        navigable_taxon = create_taxon(navigable: page)
        inventory = create_inventory

        assert_equal(product_url(product, host: Workarea.config.host), breadcrumb_url_for(product))
        assert_equal(page_url(page, host: Workarea.config.host), breadcrumb_url_for(page))
        assert_equal('https://www.example.com', breadcrumb_url_for(url_taxon))
        assert_equal(page_url(page, host: Workarea.config.host), breadcrumb_url_for(navigable_taxon))
        assert_raises(NoMethodError) { breadcrumb_url_for(inventory) }
      end
    end
  end
end
