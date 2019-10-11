class Task < ApplicationRecord
  belongs_to :user
  # after_create :generate_subtasks

  def subtasks
    case self.task_type
    when 'investigator'
      out_sub_tasks = []
      unless self.results.nil?
        subs_uuids = self.results['result']
        subs_uuids.keys.each do |sub_uuid|
          subtask = Task.where(uuid: sub_uuid).first
          if subtask
            out_sub_tasks << subtask
          else
            Rails.logger.debug("Subtask not found, creating it...")
            data = PersonalResearchAssistantService.get_analysis_task sub_uuid
            Task.create(user: self.user, status: data['task_status'], uuid: data['uuid'],
                        started: data['task_started'], finished: data['task_finished'],
                        task_type: data['task_type'], parameters: data['task_parameters'],
                        results: data['task_result'], subtask: true)
          end
        end
      end
      out_sub_tasks
    else
      []
    end
  end

  # private
  #
  # def generate_subtasks
  #   unless self.results.nil?
  #     if self.task_type == 'investigator'
  #       subs_uuids = self.results['result']
  #       subs_uuids.keys.each do |sub_uuid|
  #         data = PersonalResearchAssistantService.get_analysis_task sub_uuid
  #         Task.create(user: self.user, status: data['task_status'], uuid: data['uuid'],
  #                     started: data['task_started'], finished: data['task_finished'],
  #                     task_type: data['task_type'], parameters: data['task_parameters'],
  #                     results: data['task_result'], subtask: true)
  #       end
  #     end
  #   end
  # end

end