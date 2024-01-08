# frozen_string_literal: true

require "test_helper"

module PlatformosCheck
  class ImgLazyLoadingTest < Minitest::Test
    def test_no_offense_with_loading_lazy_attribute
      offenses = analyze_platformos_app(
        ImgLazyLoading.new,
        "app/views/pages/index.liquid" => <<~END
          <img src="a.jpg" loading="lazy">
          <img src="a.jpg" loading="eager">
          <img src="a.jpg" loading="LAZY">
          <img src="a.jpg" LOADING="LAZY">
        END
      )

      assert_offenses("", offenses)
    end

    def test_reports_missing_loading_lazy_attribute
      offenses = analyze_platformos_app(
        ImgLazyLoading.new,
        "app/views/pages/index.liquid" => <<~END
          <img src="a.jpg" height="{{ height }}">
        END
      )

      assert_offenses(<<~END, offenses)
        Use loading="eager" for images visible in the viewport on load and loading="lazy" for others at app/views/pages/index.liquid:1
      END
    end

    def test_autocorrect_missing_loading_lazy_attribute
      expected_sources = {
        "app/views/pages/index.liquid" => <<~END
          <div>
            <p>Hello {{ user.first_name }}</p>
            <p><img src="a.jpg" height="{{ height }}" loading="eager"></p>
          </div>
        END
      }
      sources = fix_platformos_app(
        ImgLazyLoading.new,
        "app/views/pages/index.liquid" => <<~END
          <div>
            <p>Hello {{ user.first_name }}</p>
            <p><img src="a.jpg" height="{{ height }}"></p>
          </div>
        END
      )

      sources.each do |path, source|
        assert_equal(expected_sources[path], source)
      end
    end

    def test_prefer_lazy_to_auto
      offenses = analyze_platformos_app(
        ImgLazyLoading.new,
        "app/views/pages/index.liquid" => <<~END
          <img src="a.jpg" loading="auto">
        END
      )

      assert_offenses(<<~END, offenses)
        Use loading="eager" for images visible in the viewport on load and loading="lazy" for others at app/views/pages/index.liquid:1
      END
    end
  end
end
