# frozen_string_literal: true

module PlatformosCheck
  module PlatformosLiquid
    module SourceTestHelper
      # Use a documentation folder in the test/ directory by default
      DOCUMENTATION_FIXTURE_DIRECTORY = Pathname.new("#{__dir__}/../data/platformos_liquid/documentation")

      class FakeSourceManager < SourceManager
        class << self
          def default_destination
            @default_destination ||= Pathname.new(Dir.mktmpdir)
          end

          def open_uri(remote)
            # read file from fixture
            file_name = remote.split('/')[-1].split('.')[0]

            path = DOCUMENTATION_FIXTURE_DIRECTORY + "#{file_name}.json"
            raise "File not found: #{path}" unless File.file?(path)

            File.read(path)
          end
        end
      end

      class FakeSourceIndex < SourceIndex
        class << self
          def local_path!(file_name, dest = default_destination)
            dest + "#{file_name}.json"
          end

          def default_destination
            @default_destination ||= Pathname.new(Dir.mktmpdir)
          end

          def built_in_objects
            []
          end
        end
      end

      def objects_uri
        @objects_uri ||= "https://documentation.platformos.com/api/liquid/objects.json"
      end

      def filters_uri
        @filters_uri ||= "https://documentation.platformos.com/api/liquid/filters.json"
      end

      def tags_uri
        @tags_uri ||= "https://documentation.platformos.com/api/liquid/tags.json"
      end

      def revision_uri
        @revision_uri ||= "https://documentation.platformos.com/api/liquid/latest.json"
      end

      def objects_content
        @objects_content ||= load_file(:objects)
      end

      def filters_content
        @filters_content ||= load_file(:filters)
      end

      def tags_content
        @tags_content ||= load_file(:tags)
      end

      def revision_content
        @revision_content ||= load_file(:latest)
      end

      def load_file(file_name)
        path = DOCUMENTATION_FIXTURE_DIRECTORY + "#{file_name}.json"
        raise "File not found: #{path}" unless File.file?(path)

        File.read(path)
      end

      def create_dummy_tags_file(destination)
        File.binwrite(destination + 'tags.json', {})
      end

      def create_out_of_date_revision_file(destination)
        File.binwrite(destination + 'latest.json', '{ "revision": "out_of_date_sha" }')
      end

      def create_documentation_in_destination(destination)
        source_manager_class = FakeSourceManager.dup

        source_manager_class.download(destination)
      end
    end
  end
end
