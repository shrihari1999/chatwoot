/* global axios */

import ApiClient from './ApiClient';

class CannedResponse extends ApiClient {
  constructor() {
    super('canned_responses', { accountScoped: true });
  }

  get({ searchKey, categoryId } = {}) {
    const params = new URLSearchParams();
    if (searchKey) params.append('search', searchKey);
    if (categoryId) params.append('category_id', categoryId);
    const query = params.toString();
    const url = query ? `${this.url}?${query}` : this.url;
    return axios.get(url);
  }
}

export default new CannedResponse();
