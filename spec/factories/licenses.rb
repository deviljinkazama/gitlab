FactoryGirl.define do
  factory :gitlab_license, class: "Gitlab::License" do
    starts_at { Date.today - 1.month }
    expires_at { Date.today + 11.months }
    licensee do
      { "Name" => generate(:name) }
    end
    restrictions do
      {
        add_ons: {
          'GitLab_FileLocks' => 1,
          'GitLab_Auditor_User' => 1
        }
      }
    end
    notify_users_at   { |l| l.expires_at }
    notify_admins_at  { |l| l.expires_at }

    trait :trial do
      restrictions do
        { trial: true }
      end
    end
  end

  factory :license do
    data { build(:gitlab_license).export }
  end

  factory :trial_license, class: License do
    data { build(:gitlab_license, :trial).export }
  end
end
