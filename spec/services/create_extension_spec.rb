require "spec_helper"

describe CreateExtension do
  let(:github_url)  { "cvincent/test" }
  let(:signed_id)   { nil }
  let(:params) { {
    name:                 "asdf",
    description:          "desc",
    github_url:           github_url,
    tag_tokens:           "tag1, tag2",
    compatible_platforms: ["", "p1", "p2"],
    tmp_source_file:      signed_id,
  } }
  let(:github)         { double(:github) }
  let(:user)           { create(:user, username: 'some_user') }
  let(:github_account) { user.github_account }
  let(:extension)      { build :extension, owner: user }

  subject { CreateExtension.new(params, user) }
  let(:normalized_attributes) { {
    'github_url'     => "https://github.com/#{github_url}",
    'lowercase_name' => "asdf",
  } }
  let(:expected_unnormalized_attributes) { Extension.new(params.merge(owner: user)).attributes }
  let(:expected_normalized_attributes)   { Extension.new(params.merge(owner: user)).attributes.merge(normalized_attributes) }

  before do
    allow(user).to receive(:octokit) { github }
    allow(github).to receive(:collaborator?).with("cvincent/test", "some_user") { true }
    allow(github).to receive(:repo).with("cvincent/test") { {} }
    allow(CollectExtensionMetadataWorker).to receive(:perform_async)
    allow(SetupExtensionWebHooksWorker).to receive(:perform_async)
    allow(NotifyModeratorsOfNewExtensionWorker).to receive(:perform_async)
  end

  after do
    # Purge ActiveStorage::Blob files.
    FileUtils.rm_rf(Rails.root.join('tmp', 'storage'))
  end

  it "saves a valid extension, returning the extension" do
    result = subject.process!
    expect(result).to be_kind_of(Extension)
    expect(result).to be_persisted
  end

  it "adds tags" do
    e = subject.process!
    expect(e.tags.size).to eq(2)
    expect(e.tag_tokens).to eq('tag1, tag2')
  end

  context 'a github extension' do
    it "kicks off a worker to gather metadata about the valid extension" do
      expect(CollectExtensionMetadataWorker).to receive(:perform_async)
      expect(subject.process!).to be_persisted
    end

    it "kicks off a worker to set up the repo's web hook for updates" do
      expect(SetupExtensionWebHooksWorker).to receive(:perform_async)
      expect(subject.process!).to be_persisted
    end

    it "kicks off a worker to notify operators" do
      expect(NotifyModeratorsOfNewExtensionWorker).to receive(:perform_async)
      expect(subject.process!).to be_persisted
    end

    it "does not check the repo collaborators if the extension is invalid" do
      allow_any_instance_of(Extension).to receive(:valid?) { false }
      expect(github).not_to receive(:collaborator?)
      expect(subject.process!.attributes).to eq(expected_unnormalized_attributes)
    end

    it "does not save and adds an error if the user is not a collaborator in the repo" do
      allow(github).to receive(:collaborator?).with("cvincent/test", "some_user") { false }
      expect_any_instance_of(Extension).not_to receive(:save)
      result = subject.process!
      expect(result.attributes).to eq(expected_normalized_attributes)
      expect(result.errors[:github_url]).to include(I18n.t("extension.github_url_format_error"))
    end

    it "does not save and adds an error if the repo is invalid" do
      allow(github).to receive(:collaborator?).with("cvincent/test", "some_user").and_raise(ArgumentError)
      expect_any_instance_of(Extension).not_to receive(:save)
      result = subject.process!
      expect(result.attributes).to eq(expected_normalized_attributes)
      expect(result.errors[:github_url]).to include(I18n.t("extension.github_url_format_error"))
    end
  end

  context 'a hosted extension' do
    let(:github_url)  { nil }
    let(:blob)        { ActiveStorage::Blob.create_after_upload!(io: StringIO.new(""), filename: 'not-really-a-file') }
    let(:signed_id)   { blob.signed_id}
    let(:extension)   { build :extension, :hosted, owner: user }

    it "creates an ExtensionVersion child for the extension" do
      expect {
        new_extension = subject.process!
        expect(new_extension.extension_versions.count).to eq(1)
      }.to change{ExtensionVersion.count}.by(1)
    end

    it "transfers the temporary source file to the ExtensionVersion child" do
      new_extension = subject.process!
      new_extension_version = new_extension.extension_versions.first
      expect(new_extension_version.source_file.signed_id).to eq(signed_id)
    end

    it "does not kick off a worker to gather metadata about the valid extension" do
      expect(CollectExtensionMetadataWorker).to_not receive(:perform_async)
      expect(subject.process!).to be_persisted
    end

    it "does not kick off a worker to set up the repo's web hook for updates" do
      expect(SetupExtensionWebHooksWorker).to_not receive(:perform_async)
      expect(subject.process!).to be_persisted
    end

    it "does not kick off a worker to notify operators" do
      expect(NotifyModeratorsOfNewExtensionWorker).to_not receive(:perform_async)
      expect(subject.process!).to be_persisted
    end
  end

  it "does not save an invalid extension, returning the extension" do
    allow_any_instance_of(Extension).to receive(:valid?) { false }
    expect_any_instance_of(Extension).not_to receive(:save)
    expect(subject.process!.attributes).to eq(expected_unnormalized_attributes)
  end
end
