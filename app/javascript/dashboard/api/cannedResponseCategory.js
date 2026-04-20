/* global axios */

import ApiClient from './ApiClient';

class CannedResponseCategoryAPI extends ApiClient {
  constructor() {
    super('canned_response_categories', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(name) {
    return axios.post(this.url, { name });
  }

  update(id, name) {
    return axios.patch(`${this.url}/${id}`, { name });
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new CannedResponseCategoryAPI();
