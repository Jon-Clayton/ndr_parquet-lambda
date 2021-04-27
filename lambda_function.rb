require 'rubygems'
require 'bundler/setup'

require 'lambda'
require 'ndr_parquet'
require 'safe_dir'

# Configure SafePath
SafePath.configure!(File.join('.', 'filesystem_paths.yml'))

class Handler
  def self.process(event:, context:)
    # Set object details
    input_bucket = event['input_bucket']
    output_bucket = event['output_bucket']
    object_key = event['object_key']
    mappings = event['mappings']

    SafeDir.mktmpdir do |safe_dir|
      npl = NdrParquet::Lambda.new(safe_dir: safe_dir)

      # Create a temporary copy of the mappings
      table_mappings = npl.materialise_mappings(mappings)

      # Create a temporary copy of the S3 file
      safe_input_path = npl.get_object(input_bucket, object_key)

      # Generate the parquet file(s)
      generator = NdrParquet::Generator.new(safe_input_path, table_mappings, safe_dir)
      generator.load

      results = []

      # Put the output files in the output S3 bucket
      generator.output_files.each do |path|
        results << npl.put_object(output_bucket, path)
      end

      return {
        versions: {
          ndr_import: NdrImport::VERSION,
          ndr_parquet: NdrParquet::VERSION,
          ruby: RUBY_VERSION
        },
        results: results
      }
    end
  end
end
