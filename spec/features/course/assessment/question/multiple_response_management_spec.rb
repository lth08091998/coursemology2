# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Course: Assessments: Questions: Multiple Response Management' do
  let(:instance) { Instance.default }

  with_tenant(:instance) do
    let(:course) { create(:course) }
    let(:assessment) { create(:assessment, course: course) }
    before { login_as(user, scope: :user) }

    context 'As a Course Manager' do
      let(:user) { create(:course_manager, course: course).user }

      scenario 'I can create a new multiple response question' do
        skill = create(:course_assessment_skill, course: course)
        visit course_assessment_path(course, assessment)
        click_link I18n.t('course.assessment.assessments.show.new_question.multiple_response')

        expect(current_path).to eq(
          new_course_assessment_question_multiple_response_path(course, assessment)
        )
        expect(page).to have_text(
          I18n.t('course.assessment.question.multiple_responses.new.multiple_response_header')
        )

        question_attributes = attributes_for(:course_assessment_question_multiple_response)
        fill_in 'title', with: question_attributes[:title]
        fill_in 'description', with: question_attributes[:description]
        fill_in 'staff_only_comments', with: question_attributes[:staff_only_comments]
        fill_in 'maximum_grade', with: question_attributes[:maximum_grade]
        within find_field('skills') do
          select skill.title
        end

        # Add an option
        correct_option_attributes =
          attributes_for(:course_assessment_question_multiple_response_option, :correct)
        within find('#new_question_multiple_response_option') do
          find('textarea.multiple-response-option').set correct_option_attributes[:option]
          find('textarea.multiple-response-explanation').set correct_option_attributes[:explanation]
          check find('input[type="checkbox"]')[:name]
        end
        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_response_button'
        )

        question_created = assessment.questions.first.specific
        expect(page).to have_content_tag_for(question_created)
        expect(question_created).not_to be_multiple_choice
        expect(question_created.skills).to contain_exactly(skill)
        expect(question_created.options).to be_present
      end

      scenario 'I can create a new multiple choice question' do
        visit course_assessment_path(course, assessment)
        click_on I18n.t('common.new')
        click_link I18n.t('course.assessment.assessments.show.new_question.multiple_choice')

        expect(current_path).to eq(
          new_course_assessment_question_multiple_response_path(course, assessment)
        )
        expect(page).to have_text(
          I18n.t('course.assessment.question.multiple_responses.new.multiple_choice_header')
        )
        question_attributes = attributes_for(:course_assessment_question_multiple_response)
        fill_in 'title', with: question_attributes[:title]
        fill_in 'maximum_grade', with: question_attributes[:maximum_grade]
        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_choice_button'
        )

        # Cannot create multiple choice question without a correct option
        expect(current_path).to eq(
          course_assessment_question_multiple_responses_path(course, assessment)
        )
        expect(page).to have_text(
          I18n.t('activerecord.errors.models.course/assessment/question/'\
                 'multiple_response.attributes.options.no_correct_option')
        )

        # Create a correct option
        correct_option_attributes =
          attributes_for(:course_assessment_question_multiple_response_option, :correct)
        within find('#new_question_multiple_response_option') do
          find('textarea.multiple-response-option').set correct_option_attributes[:option]
          find('textarea.multiple-response-explanation').set correct_option_attributes[:explanation]
          check find('input[type="checkbox"]')[:name]
        end

        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_choice_button'
        )

        expect(current_path).to eq(course_assessment_path(course, assessment))
        question_created = assessment.questions.first.specific
        expect(page).to have_content_tag_for(question_created)
        expect(question_created).to be_multiple_choice
        expect(question_created.options).to be_present
      end

      scenario 'I can edit a question and delete an option', js: true do
        mrq = create(:course_assessment_question_multiple_response, assessment: assessment,
                                                                    options: [])
        options = [
          attributes_for(:course_assessment_question_multiple_response_option, :wrong),
          attributes_for(:course_assessment_question_multiple_response_option, :correct)
        ]
        visit course_assessment_path(course, assessment)

        edit_path = edit_course_assessment_question_multiple_response_path(course, assessment, mrq)
        find_link(nil, href: edit_path).click

        maximum_grade = 999.9
        fill_in 'maximum_grade', with: maximum_grade
        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_response_button'
        )

        expect(current_path).to eq(course_assessment_path(course, assessment))
        expect(mrq.reload.maximum_grade).to eq(maximum_grade)

        visit edit_path

        options.each_with_index do |option, i|
          click_link I18n.t('course.assessment.question.multiple_responses.form.add_option')
          within all('.edit_question_multiple_response '\
            'tr.question_multiple_response_option')[i] do
            find('textarea.multiple-response-option').set option[:option]
            find('textarea.multiple-response-explanation').set option[:explanation]
            if option[:correct]
              check find('input[type="checkbox"]')[:name]
            else
              uncheck find('input[type="checkbox"]')[:name]
            end
          end
        end
        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_response_button'
        )

        expect(current_path).to eq(course_assessment_path(course, assessment))
        expect(page).to have_selector('div.alert.alert-success')
        expect(mrq.reload.options.count).to eq(options.count)

        # Delete all MRQ options
        visit edit_path
        all('tr.question_multiple_response_option').each do |element|
          within element do
            click_link I18n.t('course.assessment.question.multiple_responses.option_fields.remove')
          end
        end
        click_button I18n.t(
          'course.assessment.question.multiple_responses.form.multiple_response_button'
        )

        expect(current_path).to eq(course_assessment_path(course, assessment))
        expect(page).to have_selector('div.alert.alert-success')
        expect(mrq.reload.options.count).to eq(0)
      end

      scenario 'I can delete a question' do
        mrq = create(:course_assessment_question_multiple_response, assessment: assessment)
        visit course_assessment_path(course, assessment)

        delete_path = course_assessment_question_multiple_response_path(course, assessment, mrq)
        find_link(nil, href: delete_path).click

        expect(current_path).to eq(course_assessment_path(course, assessment))
        expect(page).not_to have_content_tag_for(mrq)
      end
    end

    context 'As a Student' do
      let(:user) { create(:course_student, course: course).user }

      scenario 'I cannot add questions' do
        visit new_course_assessment_question_multiple_response_path(course, assessment)

        expect(page.status_code).to eq(403)
      end
    end
  end
end
