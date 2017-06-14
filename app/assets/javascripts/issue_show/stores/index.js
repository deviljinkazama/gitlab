export default class Store {
  constructor({
    titleHtml,
    titleText,
    descriptionHtml,
    descriptionText,
<<<<<<< HEAD
=======
    updatedAt,
    updatedByName,
    updatedByPath,
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  }) {
    this.state = {
      titleHtml,
      titleText,
      descriptionHtml,
      descriptionText,
      taskStatus: '',
<<<<<<< HEAD
      updatedAt: '',
=======
      updatedAt,
      updatedByName,
      updatedByPath,
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
    };
    this.formState = {
      title: '',
      confidential: false,
      description: '',
      lockedWarningVisible: false,
      move_to_project_id: 0,
      updateLoading: false,
    };
  }

  updateState(data) {
    this.state.titleHtml = data.title;
    this.state.titleText = data.title_text;
    this.state.descriptionHtml = data.description;
    this.state.descriptionText = data.description_text;
    this.state.taskStatus = data.task_status;
    this.state.updatedAt = data.updated_at;
<<<<<<< HEAD
=======
    this.state.updatedByName = data.updated_by_name;
    this.state.updatedByPath = data.updated_by_path;
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
  }

  stateShouldUpdate(data) {
    return {
      title: this.state.titleText !== data.title_text,
      description: this.state.descriptionText !== data.description_text,
    };
  }

  setFormState(state) {
    this.formState = Object.assign(this.formState, state);
  }
}
