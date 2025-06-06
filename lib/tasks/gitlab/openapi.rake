# frozen_string_literal: true

YAML_DOC_INTRODUCTION = <<-INTRO
#############################################################################################
# This documentation is auto-generated by a script.                                         #
# Please do not edit this file directly.                                                    #
#                                                                                           #
# To edit the introductory text, modify `lib/tasks/gitlab/openapi.rake`.                    #
#                                                                                           #
# Run `bin/rake gitlab:openapi:generate`                                                    #
#############################################################################################

INTRO

if Rails.env.development? || Rails.env.test?
  require 'grape-swagger/rake/oapi_tasks'
  GrapeSwagger::Rake::OapiTasks.new('::API::API')
end

namespace :gitlab do
  require 'logger'

  namespace :openapi do
    task :validate do
      raise 'This task can only be run in the development environment' unless Rails.env.development?

      success = system('yarn swagger:validate doc/api/openapi/openapi_v2.yaml')
      abort('Validation of swagger document failed') unless success
    end

    task :generate do
      unless Rails.env.development? || Rails.env.test?
        raise 'This task can only be run in the development or test environment'
      end

      ENV['store'] = 'tmp/openapi.json'
      Rake::Task["oapi:fetch"].invoke(['openapi.json'])

      yaml_content = Gitlab::Json.parse(File.read('tmp/openapi_swagger_doc.json')).to_yaml

      File.write("doc/api/openapi/openapi_v2.yaml", YAML_DOC_INTRODUCTION + yaml_content)
    end

    task generate_and_check: [:generate, :validate]

    desc 'GitLab | OpenAPI | Check if OpenAPI doc are up to date'
    task check_docs: [:environment, :enable_feature_flags] do
      ENV['store'] = 'tmp/openapi.json'
      Rake::Task["oapi:fetch"].invoke(['openapi.json'])

      current_doc = Digest::SHA512.hexdigest(File.read('doc/api/openapi/openapi_v2.yaml'))
      generated_doc = Digest::SHA512.hexdigest(
        YAML_DOC_INTRODUCTION + Gitlab::Json.parse(File.read('tmp/openapi_swagger_doc.json')).to_yaml
      )

      if current_doc == generated_doc
        puts "OpenAPI documentation is up to date"
      else
        heading = '#' * 10

        puts heading
        puts '#'
        puts '# OpenAPI documentation is outdated! Please update it by running `bin/rake gitlab:openapi:generate`.'
        puts '#'
        puts heading

        if ENV['OPENAPI_CHECK_DEBUG'] == 'true'
          yaml_content = Gitlab::Json.parse(File.read('tmp/openapi_swagger_doc.json')).to_yaml
          File.write("doc/api/openapi/openapi_v2.yaml.generated", yaml_content)
          sh 'diff -u doc/api/openapi/openapi_v2.yaml doc/api/openapi/openapi_v2.yaml.generated'
        end

        abort
      end
    end
  end
end
