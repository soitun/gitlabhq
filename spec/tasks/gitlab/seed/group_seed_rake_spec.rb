# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'gitlab:seed:group_seed rake task', :silence_stdout, feature_category: :groups_and_projects do
  let(:username) { 'group_seed' }
  let!(:user) { create(:user, username: username) }
  let(:task_params) { [2, username] }

  before do
    create(:organization, :default)
    Rake.application.rake_require('tasks/gitlab/seed/group_seed')
  end

  subject { run_rake_task('gitlab:seed:group_seed', task_params) }

  it 'performs group seed successfully', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/444373' do
    expect { subject }.not_to raise_error

    group = user.groups.first

    expect(user.groups.count).to be 3
    expect(group.projects.count).to be 2
    expect(group.members.count).to be 3
    expect(group.milestones.count).to be 2
  end
end
