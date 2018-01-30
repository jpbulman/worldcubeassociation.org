# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V0::ApiController do
  describe 'GET #competitions_search' do
    let!(:comp) { FactoryBot.create(:competition, :confirmed, :visible, name: "Jfly's Competition 2015") }

    it 'requires query parameter' do
      get :competitions_search
      expect(response.status).to eq 400
      json = JSON.parse(response.body)
      expect(json["error"]).to eq "No query specified"
    end

    it "finds competition" do
      get :competitions_search, params: { q: "competition" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
    end

    it "works well with multiple parts" do
      get :competitions_search, params: { q: "Jfly Comp 15" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
    end
  end

  describe 'GET #posts_search' do
    let!(:post) { FactoryBot.create(:post, title: "post title", body: "post body") }

    it 'requires query parameter' do
      get :posts_search
      expect(response.status).to eq 400
      json = JSON.parse(response.body)
      expect(json["error"]).to eq "No query specified"
    end

    it "finds post" do
      get :posts_search, params: { q: "post title" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
    end

    it "does not find non world readable post" do
      post.update_column(:world_readable, false)
      get :posts_search, params: { q: "post title" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 0
    end
  end

  describe 'GET #users_search' do
    let(:person) { FactoryBot.create(:person, name: "Jeremy", wca_id: "2005FLEI01") }
    let!(:user) { FactoryBot.create(:user, person: person) }

    it 'requires query parameter' do
      get :users_search
      expect(response.status).to eq 400
      json = JSON.parse(response.body)
      expect(json["error"]).to eq "No query specified"
    end

    it 'finds Jeremy' do
      get :users_search, params: { q: "erem" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].select { |u| u["name"] == "Jeremy" }[0]).not_to be_nil
    end

    it 'does not find dummy accounts' do
      FactoryBot.create :dummy_user, name: "Aaron"
      get :users_search, params: { q: "aaron" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 0
    end

    it 'can find dummy accounts' do
      user.update_column(:encrypted_password, "")
      get :users_search, params: { q: "erem", include_dummy_accounts: true }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
      expect(json["result"][0]["id"]).to eq user.id
    end

    it 'can find by wca_id' do
      get :users_search, params: { q: user.wca_id }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
      expect(json["result"][0]["id"]).to eq user.id
    end

    context 'Person without User' do
      let!(:userless_person) { FactoryBot.create(:person, name: "Bob") }

      it "can find by wca_id" do
        get :users_search, params: { q: userless_person.wca_id, persons_table: true }
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json["result"].length).to eq 1
        expect(json["result"][0]["id"]).to eq userless_person.wca_id
        expect(json["result"][0]["wca_id"]).to eq userless_person.wca_id
        expect(json['result'][0]['avatar']['url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['result'][0]['avatar']['thumb_url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['result'][0]['avatar']['is_default']).to eq true
      end

      it "can find by name" do
        get :users_search, params: { q: "bo", persons_table: true }
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json["result"].length).to eq 1
        expect(json["result"][0]["id"]).to eq userless_person.wca_id
        expect(json["result"][0]["wca_id"]).to eq userless_person.wca_id
      end
    end

    it 'does not find unconfirmed accounts' do
      user.update_column(:confirmed_at, nil)
      get :users_search, params: { q: "erem" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 0
    end

    it 'can only find delegates' do
      delegate = FactoryBot.create(:delegate, name: "Jeremy")
      get :users_search, params: { q: "erem", only_delegates: true }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
      expect(json["result"][0]["id"]).to eq delegate.id
    end
  end

  describe 'GET #omni_search' do
    let!(:user) { FactoryBot.create(:user_with_wca_id, name: "Jeremy Fleischman") }
    let!(:comp) { FactoryBot.create(:competition, :confirmed, :visible, name: "jeremy Jfly's Competition 2015", delegates: [user]) }
    let!(:post) { FactoryBot.create(:post, title: "jeremy post title", body: "post body", author: user) }

    it 'requires query parameter' do
      get :omni_search
      expect(response.status).to eq 400
      json = JSON.parse(response.body)
      expect(json["error"]).to eq "No query specified"
    end

    it "finds all the things!" do
      get :omni_search, params: { q: "jeremy" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 2
      expect(json["result"].count { |r| r["class"] == "competition" }).to eq 1
      expect(json["result"].count { |r| r["class"] == "post" }).to eq 0
      expect(json["result"].count { |r| r["class"] == "user" }).to eq 0
      expect(json["result"].count { |r| r["class"] == "person" }).to eq 1
    end

    it "works well when parts of the name are given" do
      get :omni_search, params: { q: "Flei Jer" }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["result"].length).to eq 1
      expect(json["result"][0]["name"]).to include "Jeremy Fleischman"
    end
  end

  describe 'show_user_*' do
    it 'can query by id' do
      user = FactoryBot.create(:user, name: "Jeremy")
      get :show_user_by_id, params: { id: user.id }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["user"]["name"]).to eq "Jeremy"
      expect(json["user"]["wca_id"]).to eq user.wca_id
    end

    it 'can query by wca id' do
      user = FactoryBot.create(:user_with_wca_id)
      get :show_user_by_wca_id, params: { wca_id: user.wca_id }
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["user"]["name"]).to eq user.name
      expect(json["user"]["wca_id"]).to eq user.wca_id
    end

    it '404s nicely' do
      get :show_user_by_wca_id, params: { wca_id: "foo" }
      expect(response.status).to eq 404
      json = JSON.parse(response.body)
      expect(json["user"]).to be nil
    end
  end

  describe 'GET #delegates' do
    it 'includes emails and regions' do
      senior_delegate = FactoryBot.create :senior_delegate
      delegate = FactoryBot.create :delegate, region: "SF bay area, USA", senior_delegate: senior_delegate

      get :delegates
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json.length).to eq 2

      delegate_json = json.find { |user| user["id"] == delegate.id }
      expect(delegate_json["email"]).to eq delegate.email
      expect(delegate_json["region"]).to eq "SF bay area, USA"
      expect(delegate_json["senior_delegate_id"]).to eq senior_delegate.id
    end

    it 'paginates' do
      30.times do
        FactoryBot.create :delegate
      end

      get :delegates
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json.length).to eq 25

      # Parse HTTP Link header mess
      link = response.headers["Link"]
      links = link.split(/, */)
      next_link = links[1]
      url, rel = next_link.split(/; */)
      url = url[1...-1]
      expect(rel).to eq 'rel="next"'

      get :delegates, params: Rack::Utils.parse_query(URI(url).query)
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json.length).to eq User.delegates.count - 25
    end
  end

  describe 'GET #scramble_program' do
    it 'works' do
      get :scramble_program
      expect(response.status).to eq 200
      json = JSON.parse(response.body)
      expect(json["current"]["name"]).to eq "TNoodle-WCA-0.13.1"
    end
  end

  describe 'GET #me' do
    context 'not signed in' do
      it 'returns 401' do
        get :me
        expect(response.status).to eq 401
        json = JSON.parse(response.body)
        expect(json['error']).to eq("Not authorized")
      end
    end

    context 'signed in as board member' do
      before :each do
        api_sign_in_as(FactoryBot.create(:user, :board_member))
      end

      it 'has correct team membership' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)

        expect(json['me']['teams']).to match_array [
          { "friendly_id" => "board", "leader" => false },
        ]
      end
    end

    context 'signed in as senior delegate' do
      before :each do
        api_sign_in_as(FactoryBot.create(:senior_delegate))
      end

      it 'has correct delegate_status' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)

        expect(json['me']['delegate_status']).to eq 'senior_delegate'
      end
    end

    context 'signed in as candidate delegate' do
      before :each do
        api_sign_in_as(FactoryBot.create(:candidate_delegate))
      end

      it 'has correct delegate_status' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)

        expect(json['me']['delegate_status']).to eq 'candidate_delegate'
      end
    end

    context 'signed in as delegate' do
      before :each do
        api_sign_in_as(FactoryBot.create(:delegate))
      end

      it 'has correct delegate_status' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)

        expect(json['me']['delegate_status']).to eq 'delegate'
      end
    end

    context 'signed in as a member of some teams and a leader of others' do
      before :each do
        user = FactoryBot.create :user

        wrc_team = Team.wrc
        FactoryBot.create(:team_member, team_id: wrc_team.id, user_id: user.id)

        results_team = Team.wrt
        FactoryBot.create(:team_member, team_id: results_team.id, user_id: user.id, team_leader: true)

        api_sign_in_as(user)
      end

      it 'has correct team membership' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)

        expect(json['me']['delegate_status']).to eq nil
        expect(json['me']['teams']).to match_array [
          { "friendly_id" => "wrt", "leader" => true },
          { "friendly_id" => "wrc", "leader" => false },
        ]
      end
    end

    context 'signed in with valid wca id' do
      let(:person) do
        FactoryBot.create(
          :person,
          countryId: "USA",
          gender: "m",
          year: 1987,
          month: 12,
          day: 4,
        )
      end
      let(:user) do
        FactoryBot.create(
          :user,
          avatar: File.open(Rails.root.join("spec/support/logo.jpg")),
          wca_id: person.wca_id,
        )
      end
      let(:scopes) { Doorkeeper::OAuth::Scopes.new }
      before :each do
        api_sign_in_as(user, scopes: scopes)
      end

      it 'works' do
        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['wca_id']).to eq(user.wca_id)
        expect(json['me']['name']).to eq(user.name)

        # Verify that avatar url is a full url (starts with http(s))
        expect(json['me']['avatar']['url']).to match(/^https?/)

        expect(json['me']['country_iso2']).to eq("US")
        expect(json['me']['gender']).to eq("m")

        expect(json['me']['dob']).to eq(nil)
        expect(json['me']['email']).to eq(nil)

        expect(json['me']['delegate_status']).to eq(nil)
        expect(json['me']['teams']).to eq([])
      end

      it 'can request dob scope' do
        scopes.add("dob")

        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['dob']).to eq("1987-12-04")
        expect(json['me']['email']).to eq(nil)
      end

      it 'can request email scope' do
        scopes.add("email")

        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['email']).to eq(user.email)
      end

      it 'can request email and dob scope' do
        scopes.add("dob", "email")

        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['dob']).to eq("1987-12-04")
        expect(json['me']['email']).to eq(user.email)
      end
    end

    context 'signed in with invalid wca id' do
      let(:user) do
        u = FactoryBot.create :user, country_iso2: "US"
        u.update_column(:wca_id, "fooooo")
        u
      end
      let(:scopes) { Doorkeeper::OAuth::Scopes.new }
      let(:token) { double acceptable?: true, resource_owner_id: user.id, scopes: scopes }
      before :each do
        allow(controller).to receive(:doorkeeper_token) { token }
      end

      it 'works' do
        scopes.add("dob", "email")

        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['wca_id']).to eq(user.wca_id)
        expect(json['me']['name']).to eq(user.name)
        expect(json['me']['email']).to eq(user.email)
        expect(json['me']['avatar']['url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['me']['avatar']['thumb_url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['me']['avatar']['is_default']).to eq true

        expect(json['me']['country_iso2']).to eq "US"
        expect(json['me']['gender']).to eq "m"
        expect(json['me']['dob']).to eq user.dob.strftime("%F")
      end
    end

    context 'signed in without wca id' do
      let(:user) { FactoryBot.create :user, country_iso2: "US" }
      let(:scopes) { Doorkeeper::OAuth::Scopes.new }
      let(:token) { double acceptable?: true, resource_owner_id: user.id, scopes: scopes }
      before :each do
        allow(controller).to receive(:doorkeeper_token) { token }
      end

      it 'works' do
        scopes.add("dob", "email")

        get :me
        expect(response.status).to eq 200
        json = JSON.parse(response.body)
        expect(json['me']['wca_id']).to eq(user.wca_id)
        expect(json['me']['name']).to eq(user.name)
        expect(json['me']['email']).to eq(user.email)
        expect(json['me']['avatar']['url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['me']['avatar']['thumb_url']).to eq AvatarUploaderBase.missing_avatar_thumb_url
        expect(json['me']['avatar']['is_default']).to eq true

        expect(json['me']['country_iso2']).to eq "US"
        expect(json['me']['gender']).to eq "m"
        expect(json['me']['dob']).to eq user.dob.strftime("%F")
      end
    end
  end
end