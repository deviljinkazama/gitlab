class ServiceHook < WebHook
  belongs_to :service

<<<<<<< HEAD
  def execute(data, hook_name = 'service_hook')
    WebHookService.new(self, data, hook_name).execute
=======
  def execute(data)
    WebHookService.new(self, data, 'service_hook').execute
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  end
end
