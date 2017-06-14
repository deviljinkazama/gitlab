import Cache from './cache';

class AjaxCache extends Cache {
  constructor() {
    super();
    this.pendingRequests = { };
  }

<<<<<<< HEAD
  retrieve(endpoint) {
    if (this.hasData(endpoint)) {
=======
  retrieve(endpoint, forceRetrieve) {
    if (this.hasData(endpoint) && !forceRetrieve) {
>>>>>>> 0d9311624754fbc3e0b8f4a28be576e48783bf81
      return Promise.resolve(this.get(endpoint));
    }

    let pendingRequest = this.pendingRequests[endpoint];

    if (!pendingRequest) {
      pendingRequest = new Promise((resolve, reject) => {
        // jQuery 2 is not Promises/A+ compatible (missing catch)
        $.ajax(endpoint) // eslint-disable-line promise/catch-or-return
        .then(data => resolve(data),
          (jqXHR, textStatus, errorThrown) => {
            const error = new Error(`${endpoint}: ${errorThrown}`);
            error.textStatus = textStatus;
            reject(error);
          },
        );
      })
      .then((data) => {
        this.internalStorage[endpoint] = data;
        delete this.pendingRequests[endpoint];
      })
      .catch((error) => {
        delete this.pendingRequests[endpoint];
        throw error;
      });

      this.pendingRequests[endpoint] = pendingRequest;
    }

    return pendingRequest.then(() => this.get(endpoint));
  }
}

export default new AjaxCache();
