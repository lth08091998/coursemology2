# frozen_string_literal: true
FactoryGirl.define do
  base_time = Time.zone.now.to_i
  sequence :host do |n|
    "local-#{base_time}-#{n}.lvh.me"
  end

  factory :instance do
    sequence(:name) { |n| "Instance#{n}" }
    host

    trait :with_video_component_enabled do
      after(:build) do |instance|
        instance.settings(:components, :course_videos_component).enabled = true
      end
    end
  end
end
