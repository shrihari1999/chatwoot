/* global axios */

import ApiClient from './ApiClient';

class CannedResponseCategoryAPI extends ApiClient {
  constructor() {
    super('canned_response_categories', { accountScoped: true });
  }

  get() {
    return axios.get(this.url);
  }

  create(payload) {
    return axios.post(this.url, payload);
  }

  update(id, payload) {
    return axios.patch(`${this.url}/${id}`, payload);
  }

  delete(id) {
    return axios.delete(`${this.url}/${id}`);
  }
}

export default new CannedResponseCategoryAPI();
